function Get-SPChildItem
{
	[CmdletBinding()]
	param (
		[PsfValidateScript('SPOTools.Validate.SharePointOnlineSite', ErrorString = 'SPOTools.Validate.SharePointOnlineSite')]
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[switch]
		$Recurse,
		
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
		$siteQualifiedHostName = $Path -replace '^(https://.+?\.sharepoint\.com/sites/.+?/).+$', '$1'
		try { Connect-PnPOnline -ClientId $ClientId -Tenant $Tenant -Thumbprint $CertificateThumbprint -Url $siteQualifiedHostName -ErrorAction Stop }
		catch
		{
			Stop-PSFFunction -Message "Failed to connect to $siteQualifiedHostName" -ErrorRecord $_ -Target $siteQualifiedHostName -EnableException $EnableException
			return
		}
	}
	process
	{
		if (Test-PSFFunctionInterrupt) { return }
		
		Get-PnPFolderItem -FolderSiteRelativeUrl $Path.Replace($siteQualifiedHostName, '') -Recursive:$Recurse -ErrorAction Stop | ForEach-Object {
			$_ -as [SPOTools.SharePointObject]
		} | Add-Member -MemberType NoteProperty -Name BasePath -Value $Path -PassThru | Add-Member -MemberType ScriptProperty -Name BaseRelativePath -Value { $this.HostPath.Replace($this.BasePath, '') } -PassThru
	}
}