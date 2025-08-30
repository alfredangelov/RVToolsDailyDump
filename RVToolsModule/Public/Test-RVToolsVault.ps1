function Test-RVToolsVault {
    <#
    .SYNOPSIS
        Tests if a SecretManagement vault exists and is accessible.

    .DESCRIPTION
        This function validates that the specified SecretManagement vault exists
        and can be accessed for storing and retrieving RVTools credentials.

    .PARAMETER VaultName
        Name of the SecretManagement vault to test.

    .EXAMPLE
        Test-RVToolsVault -VaultName "RVToolsVault"

    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VaultName
    )
    
    try {
        $vault = Get-SecretVault -Name $VaultName -ErrorAction Stop
        return $null -ne $vault
    } catch {
        Write-RVToolsLog -Message "Vault '$VaultName' not found or inaccessible: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}
