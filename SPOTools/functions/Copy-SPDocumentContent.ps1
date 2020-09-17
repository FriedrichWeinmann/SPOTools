function Copy-SPDocumentContent
{
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[PsfValidateScript('SPOTools.Validate.SharePointOnlineSite', ErrorString = 'SPOTools.Validate.SharePointOnlineSite')]
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[string]
		$SourceUrl,
		
		[PsfValidateScript('SPOTools.Validate.SharePointOnlineSite', ErrorString = 'SPOTools.Validate.SharePointOnlineSite')]
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[string]
		$TargetUrl,
		
		[switch]
		$Direct,
		
		[switch]
		$NoRecurse,
		
		[Parameter(Mandatory = $true)]
		[string]
		$Tenant,
		
		[Parameter(Mandatory = $true)]
		[string]
		$ClientID,
		
		[Parameter(Mandatory = $true)]
		[string]
		$CertificateThumbprint,
		
		[switch]
		$EnableException
	)
	
	begin
	{
		function Copy-SPItem
		{
			[CmdletBinding()]
			param (
				$Connection,
				
				[string]
				$TargetUrl,
				
				[AllowEmptyString()]
				[string]
				$TargetRelativePath,
				
				$SourceItem,
				
				[string]
				$SourceUrl,
				
				[bool]
				$NoRecurse
			)
			
			if ($SourceItem -is [Microsoft.SharePoint.Client.Folder])
			{
				$newRelativePath = ($TargetRelativePath, $SourceItem.Name -join "/").Trim('/')
				$newSourcePath = $SourceUrl, $SourceItem.Name -join "/"
				Invoke-PSFProtectedCommand -Action "Resolving path: '$newRelativePath' on $TargetUrl" -Target $TargetUrl -ScriptBlock {
					$null = Resolve-PnPFolder -SiteRelativePath $newRelativePath -Connection $Connection -ErrorAction Stop
				} -EnableException $true -PSCmdlet $PSCmdlet
				
				foreach ($entry in Get-PnPFolderItem -Identity $newSourcePath)
				{
					if ($NoRecurse) { break }
					Copy-SPItem -Connection $Connection -TargetUrl $TargetUrl -TargetRelativePath $newRelativePath -SourceItem $entry -SourceUrl $newSourcePath
				}
			}
			else
			{
				$targetSiteRoot = $TargetUrl -replace '(.+?/sites/.+?)/.+$', '$1'
				$sourceFile = $SourceUrl, $SourceItem.Name -join "/" -replace '^.+?/sites/.+?/'
				$targetPath = $targetSiteRoot, $TargetRelativePath -join "/" -replace 'https://.+?/', '/'
				Invoke-PSFProtectedCommand -Action "Copying $sourceFile to $targetPath" -Target $targetPath -ScriptBlock {
					Copy-PnPFile -SourceUrl $sourceFile.Replace('#','%23') -TargetUrl $targetPath.Replace('#','%23') -OverwriteIfAlreadyExists -Force -ErrorAction Stop
				} -PSCmdlet $PSCmdlet
			}
		}
	}
	process
	{
		$targetHost = $TargetUrl -replace '^(.+?/sites/[^/]+).+$', '$1'
		try { $targetConnection = Connect-PnPOnline -ClientId $ClientId -Tenant $Tenant -Thumbprint $CertificateThumbprint -Url $targetHost -ErrorAction Stop -ReturnConnection }
		catch
		{
			Stop-PSFFunction -Message "Failed to connect to $targetHost" -ErrorRecord $_ -Target $targetHost -EnableException $EnableException
			return
		}
		$sourceHost = $SourceUrl -replace '^(.+?/sites/[^/]+).+$', '$1'
		try { Connect-PnPOnline -ClientId $ClientId -Tenant $Tenant -Thumbprint $CertificateThumbprint -Url $sourceHost -ErrorAction Stop }
		catch
		{
			Stop-PSFFunction -Message "Failed to connect to $sourceHost" -ErrorRecord $_ -Target $sourceHost -EnableException $EnableException
			return
		}
		
		if ($destFolder = $TargetUrl.Replace($targetHost, "").Trim("/"))
		{
			Invoke-PSFProtectedCommand -Action "Creating destination folder: $destFolder" -Target $destFolder -ScriptBlock {
				$null = Resolve-PnPFolder -SiteRelativePath $destFolder -Connection $targetConnection -ErrorAction Stop
			} -EnableException $true -PSCmdlet $PSCmdlet
			
		}
		
		if ($Direct)
		{
			$effectiveSourceUrl = $SourceUrl -replace '/[^/]+$'
			try { $item = Get-PnPFile -Url $SourceUrl -ErrorAction Stop }
			catch
			{
				try { $item = Get-PnPFolder -Url $SourceUrl -ErrorAction Stop }
				catch
				{
					Stop-PSFFunction -Message "Error accessing $SourceUrl" -EnableException $true -Cmdlet $PSCmdlet -ErrorRecord $_
				}
			}
			Copy-SPItem -Connection $targetConnection -TargetUrl $TargetUrl -TargetRelativePath $destFolder -SourceItem $item -SourceUrl $effectiveSourceUrl -NoRecurse $NoRecurse
		}
		else
		{
			foreach ($item in Get-PnPFolderItem -Identity $SourceUrl)
			{
				Copy-SPItem -Connection $targetConnection -TargetUrl $TargetUrl -TargetRelativePath $destFolder -SourceItem $item -SourceUrl $SourceUrl -NoRecurse $NoRecurse
			}
		}
	}
}