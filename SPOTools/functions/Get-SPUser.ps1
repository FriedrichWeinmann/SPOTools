function Get-SPUser
{
<#
	.SYNOPSIS
		Returns user accounts associated with a given sharepoint online site.
	
	.DESCRIPTION
		Returns user accounts associated with a given sharepoint online site.
	
	.PARAMETER Site
		The site for which to return the user.
		Can be either the name or the full url to the site.
	
	.PARAMETER Name
		Name of the user to filter by.
		Defaults to *
	
	.PARAMETER IncludeRights
		Resolve the specific permissions of the user?
	
	.PARAMETER IncludeSystemAccounts
		Whether to also process system accounts.
		By default, system accounts are not displayed.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Get-PNPTenantSite -Filter 'Url -like "*/sites/*"' | Get-SPUser
	
		Return all users from all sites.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('Url')]
		[string[]]
		$Site,
		
		[string]
		$Name = '*',
		
		[switch]
		$IncludeRights,
		
		[switch]
		$IncludeSystemAccounts,
		
		[switch]
		$EnableException
	)
	
	begin
	{
		#region Utility Functions
		function Get-SitePermission
		{
			[CmdletBinding()]
			param (
				[string]
				$LoginName
			)
			
			$allPermissions = 'EmptyMask', 'ViewListItems', 'AddListItems', 'EditListItems', 'DeleteListItems', 'ApproveItems', 'OpenItems', 'ViewVersions', 'DeleteVersions', 'CancelCheckout', 'ManagePersonalViews', 'ManageLists', 'ViewFormPages', 'AnonymousSearchAccessList', 'Open', 'ViewPages', 'AddAndCustomizePages', 'ApplyThemeAndBorder', 'ApplyStyleSheets', 'ViewUsageData', 'CreateSSCSite', 'ManageSubwebs', 'CreateGroups', 'ManagePermissions', 'BrowseDirectories', 'BrowseUserInfo', 'AddDelPrivateWebParts', 'UpdatePersonalWebParts', 'ManageWeb', 'AnonymousSearchAccessWebLists', 'UseClientIntegration', 'UseRemoteAPIs', 'ManageAlerts', 'CreateAlerts', 'EditMyUserInfo', 'EnumeratePermissions', 'FullMask'
			
			$web = Get-PnPWeb
			$userEffectivePermission = $web.GetUserEffectivePermissions($LoginName)
			try { Invoke-PnPQuery -ErrorAction stop }
			catch { throw }
			
			foreach ($permission in $allPermissions)
			{
				if ($userEffectivePermission.Value.Has($permission)) { $permission }
			}
		}
		#endregion Utility Functions
		
		Assert-SPConnection -Cmdlet $PSCmdlet
	}
	process
	{
		foreach ($siteName in $Site)
		{
			Invoke-PSFProtectedCommand -Action Connecting -Target $siteName -ScriptBlock {
				Connect-SPService -Site $siteName -EnableException
			} -EnableException $EnableException -PSCmdlet $PSCmdlet -Continue
			
			foreach ($user in Get-PnPUser)
			{
				if ($user.Title -notlike $Name -and $user.Email -notlike $Name) { continue }
				if (-not $IncludeSystemAccounts -and $user.LoginName -match '^c:0\(\.s|^c:0-\.f|^i:0#\.w\|nt service\\spsearch$|^i:0i\.t\|.+\|app@sharepoint$|^SHAREPOINT\\system$') { continue }
				Write-PSFMessage -Message "Processing $($user.Title) | $($user.Email) ($($user.LoginName))" -Target $siteName
				
				$object = [PSCustomObject]@{
					PSTypeName = 'SPOTools.Site.User'
					Site	   = $siteName
					SiteName   = (Get-PnPConnection).Url -replace '.+/'
					User	   = $user.Title
					UserMail   = $user.Email
					UserLogin  = $user.LoginName
					UserID	   = $user.Id
					Permissions = $null
					PermissionsError = $null
					UserObject = $user
				}
				
				if ($IncludeRights)
				{
					try { $object.Permissions = Get-SitePermission -LoginName $user.LoginName }
					catch { $object.PermissionError = $_ }
				}
				
				$object
			}
		}
	}
}