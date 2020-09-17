function Compare-SPDocumentStructure
{
	[CmdletBinding()]
	param (
		[PsfValidateScript('SPOTools.Validate.SharePointOnlineSite', ErrorString = 'SPOTools.Validate.SharePointOnlineSite')]
		[Parameter(Mandatory = $true)]
		[string]
		$ReferencePath,
		
		[PsfValidateScript('SPOTools.Validate.SharePointOnlineSite', ErrorString = 'SPOTools.Validate.SharePointOnlineSite')]
		[Parameter(Mandatory = $true)]
		[string]
		$DifferencePath,
		
		[ValidateSet('>', '<', '==')]
		[string[]]
		$Include = @('<', '>'),
		
		[Parameter(Mandatory = $true)]
		[string]
		$Tenant,
		
		[Parameter(Mandatory = $true)]
		[string]
		$ClientID,
		
		[Parameter(Mandatory = $true)]
		[string]
		$CertificateThumbprint
	)
	
	function New-Result
	{
		[CmdletBinding()]
		param (
			$ReferenceObject,
			
			$DifferenceObject
		)
		
		$type = '=='
		if (-not $ReferenceObject) { $Type = '<' }
		if (-not $DifferenceObject) { $Type = '>' }
		
		$relativePath = $ReferenceObject.BaseRelativePath
		if (-not $relativePath) { $relativePath = $DifferenceObject.BaseRelativePath }
		
		[PSCustomObject]@{
			PSTypeName	     = 'Sharepoint.Item.Comparison'
			Type			 = $type
			BaseRelativePath = $relativePath
			RefHostPath	     = $ReferenceObject.HostPath
			RefSiteRelativePath = $ReferenceObject.SiteRelativePath
			DifHostPath	     = $DifferenceObject.HostPath
			DifSiteRelativePath = $DifferenceObject.SiteRelativePath
			RefObject	     = $ReferenceObject
			DifObject	     = $DifferenceObject
		}
	}
	
	$parameters = $PSBoundParameters | ConvertTo-PSFHashtable -Include Tenant, ClientID, CertificateThumbprint
	
	try { $referenceItems = Get-SPChildItem -Path $ReferencePath -Recurse @parameters -ErrorAction Stop -EnableException }
	catch { Stop-PSFFunction -Message "Failed to process reference: $ReferencePath" -Target $ReferencePath -ErrorRecord $_ -EnableException $true }
	try { $differenceItems = Get-SPChildItem -Path $DifferencePath -Recurse @parameters -ErrorAction Stop -EnableException }
	catch { Stop-PSFFunction -Message "Failed to process difference: $DifferencePath" -Target $DifferencePath -ErrorRecord $_ -EnableException $true }
	
	# Exists in reference but not in difference
	if ('>' -in $Include)
	{
		foreach ($referenceItem in $referenceItems)
		{
			if ($referenceItem.BaseRelativePath -in $differenceItems.BaseRelativePath) { continue }
			
			New-Result -ReferenceObject $referenceItem
		}
	}
	if ('<' -in $Include)
	{
		foreach ($differenceItem in $differenceItems)
		{
			if ($differenceItem.BaseRelativePath -in $referenceItems.BaseRelativePath) { continue }
			
			New-Result -DifferenceObject $differenceItem
		}
	}
	if ('==' -in $Include)
	{
		if (-not $referenceItems) { return }
		
		$referenceBasePath = $referenceItems[0].BasePath
		$groups = @($referenceItems) + @($differenceItems) | Group-Object -Property BaseRelativePath
		foreach ($group in $groups)
		{
			if ($group.Count -ne 2) { continue }
			
			New-Result -ReferenceObject ($group.Group | Where-Object BasePath -EQ $referenceBasePath) -DifferenceObject ($group.Group | Where-Object BasePath -NE $referenceBasePath)
		}
	}
}