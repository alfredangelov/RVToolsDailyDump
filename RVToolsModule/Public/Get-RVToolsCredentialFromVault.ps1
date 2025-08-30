function Get-RVToolsCredentialFromVault {
    <#
    .SYNOPSIS
        Retrieves credentials from SecretManagement vault for RVTools operations.

    .DESCRIPTION
        This function retrieves stored credentials from the SecretManagement vault
        with fallback to interactive prompts if SecretManagement fails.

    .PARAMETER HostName
        The vCenter hostname for credential lookup.

    .PARAMETER Username
        The username for credential lookup.

    .PARAMETER VaultName
        Name of the SecretManagement vault.

    .PARAMETER SecretPattern
        Pattern for generating secret names (e.g., '{HostName}-{Username}').

    .PARAMETER AuthMethod
        Authentication method: 'SecretManagement' or 'Prompt'.

    .PARAMETER DryRun
        Skip actual credential retrieval for dry-run scenarios.

    .EXAMPLE
        $cred = Get-RVToolsCredentialFromVault -HostName "vcenter01.local" -Username "admin" -VaultName "RVToolsVault"

    .OUTPUTS
        System.Management.Automation.PSCredential
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HostName,
        
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter()]
        [string]$VaultName = 'RVToolsVault',
        
        [Parameter()]
        [string]$SecretPattern = '{HostName}-{Username}',
        
        [Parameter()]
        [ValidateSet('SecretManagement', 'Prompt')]
        [string]$AuthMethod = 'SecretManagement',
        
        [Parameter()]
        [switch]$DryRun
    )
    
    if ($DryRun) {
        Write-RVToolsLog -Message "Dry-run: Skipping credential retrieval for $Username on $HostName" -Level 'DEBUG'
        return $null
    }
    
    $cred = $null
    
    # Try SecretManagement first if configured
    if ($AuthMethod -eq 'SecretManagement') {
        try {
            $secretName = Get-RVToolsSecretName -HostName $HostName -Username $Username -Pattern $SecretPattern
            Write-RVToolsLog -Message "Looking for secret: $secretName in vault: $VaultName" -Level 'DEBUG'
            $cred = Get-Secret -Name $secretName -Vault $VaultName -ErrorAction Stop
            Write-RVToolsLog -Message "Retrieved credential for $Username on $HostName from SecretManagement" -Level 'DEBUG'
        } catch {
            Write-RVToolsLog -Message "Failed to retrieve credential for $Username on $HostName from SecretManagement: $($_.Exception.Message)" -Level 'WARN'
            Write-RVToolsLog -Message "Falling back to prompt authentication" -Level 'INFO'
        }
    }
    
    # Fall back to prompt if SecretManagement failed or not configured
    if (-not $cred) {
        $cred = Get-Credential -UserName $Username -Message "Enter password for $Username on $HostName"
    }
    
    return $cred
}
