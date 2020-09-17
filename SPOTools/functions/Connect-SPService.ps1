function Connect-SPService
{
<#
	.SYNOPSIS
		Establishes and manages a sharepoint connection using a service principal and certificate based authentication.
	
	.DESCRIPTION
		Establishes and manages a sharepoint connection using a service principal and certificate based authentication.
		Tenant, ClientID and CertificateThumbprint need only be specified once.
		
		Neither Url nor Site are required.
		If no resource to connect to is specified, only the authentication settings will be stored.
		In the same way, specifying authentication settings is optional if already set once - they will be remembered and reused.
		
		Actual connection will be made using Connect-PNPOnline and is valid for regular pnp commands.
	
	.PARAMETER Tenant
		The name of the tenant.
		E.g.: contoso.onmicrosoft.com.
	
	.PARAMETER ClientID
		The ClientID / ApplicationID of the Service Principal.
	
	.PARAMETER Thumbprint
		Thumbprint of the authentication certificate registered with the Service Principal.
		Must be registered to the local certificate store of the user.
	
	.PARAMETER Certificate
		Full certificate object of the cert to use for authentication.
		Requires private key access.
	
	.PARAMETER Url
		Full url to connect to.
	
	.PARAMETER Site
		Site to connect to.
		Can be either name or full url.
	
	.PARAMETER ReturnConnection
		Whether to return the connection object.
		Has no effect if neither Site nor Url parameter are bound.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Connect-SPService -Tenant contoso.onmicrosoft.com -ClientID $clientID -Thumbprint $thumbprint -Url $url
		
		Connects to the contoso tenant with the specified client app and certificate, targeting the specified url.
	
	.EXAMPLE
		PS C:\> Connect-SPService -Tenant contoso.onmicrosoft.com -ClientID $clientID -Thumbprint $thumbprint
		
		Prepares the credentials for subsequent SharePoint online calls, but does not establish actual connections.
	
	.EXAMPLE
		PS C:\> Connect-SPService -Site marketing
		
		Establishes a connection to the marketing site.
#>
	[CmdletBinding()]
	Param (
		[string]
		$Tenant,
		
		[string]
		$ClientID,
		
		[string]
		$Thumbprint,
		
		[System.Security.Cryptography.X509Certificates.X509Certificate2]
		$Certificate,
		
		[string]
		$Url,
		
		[string]
		$Site,
		
		[switch]
		$ReturnConnection,
		
		[switch]
		$EnableException
	)
	
	process
	{
		#region Authentication
		if ($Tenant) { $script:con_tenant = $Tenant }
		if ($ClientID) { $script:con_clientid = $ClientID }
		if ($Thumbprint)
		{
			$script:con_certificate = $null
			$script:con_thumbprint = $Thumbprint
		}
		if ($Certificate)
		{
			$script:con_certificate = $Certificate
			$script:con_thumbprint = $null
		}
		
		$authParam = @{
			Tenant = $script:con_tenant
			ClientID = $script:con_clientid
		}
		if ($script:con_certificate) { $authParam.Certificate = $script:con_certificate }
		if ($script:con_thumbprint) { $authParam.Thumbprint = $script:con_thumbprint }
		#endregion Authentication
		
		#region Connection
		if ($Url)
		{
			Assert-SPConnection -Cmdlet $PSCmdlet
			Invoke-PSFProtectedCommand -Action "Connecting" -Target $Url -ScriptBlock {
				Connect-PnPOnline @authParam -Url $Url -ReturnConnection:$ReturnConnection
			} -EnableException $EnableException -PSCmdlet $PSCmdlet
			
		}
		elseif ($Site)
		{
			Assert-SPConnection -Cmdlet $PSCmdlet
			$siteUri = $Site -as [uri]
			if ($siteUri.IsAbsoluteUri)
			{
				Invoke-PSFProtectedCommand -Action "Connecting" -Target $Site -ScriptBlock {
					Connect-PnPOnline @authParam -Url $Site -ReturnConnection:$ReturnConnection
				} -EnableException $EnableException -PSCmdlet $PSCmdlet
			}
			else
			{
				$siteName = ($Site -replace '/{0,1}sites/' -split '/')[0]
				$connectionUri = (Get-PnPConnection).Url -as [uri]
				$tenantBaseName = $Tenant -replace '\..+$'
				
				Invoke-PSFProtectedCommand -Action "Connecting" -Target "https://$tenantBaseName.sharepoint.com/sites/$siteName" -ScriptBlock {
					Connect-PnPOnline @authParam -Url "https://$tenantBaseName.sharepoint.com/sites/$siteName" -ReturnConnection:$ReturnConnection
				} -EnableException $EnableException -PSCmdlet $PSCmdlet
			}
		}
		#endregion Connection
	}
}