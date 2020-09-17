function Assert-SPConnection
{
	[CmdletBinding()]
	Param (
		$Cmdlet
	)
	
	process
	{
		if ($script:con_tenant -and $script:con_clientid -and ($script:con_certificate -or $script:con_thumprint)) { return }
		
		$exception = [System.InvalidOperationException]::new('Not yet connected to Sharepoint Online. Use Connect-SPService to establish a connection!')
		$errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "NotConnected", 'InvalidOperation', $null)
		$Cmdlet.ThrowTerminatingError($errorRecord)
	}
}