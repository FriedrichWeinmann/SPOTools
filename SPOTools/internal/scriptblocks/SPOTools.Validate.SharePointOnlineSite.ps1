Set-PSFScriptblock -Name SPOTools.Validate.SharePointOnlineSite -Scriptblock {
	$_ -like 'https://*.sharepoint.com/sites/*'
}