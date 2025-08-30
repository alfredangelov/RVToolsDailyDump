<#
.SYNOPSIS
    Manage Microsoft Graph ClientSecret in SecretManagement vault.

.DESCRIPTION
    This script helps store, retrieve, update, and remove Microsoft Graph ClientSecret
    credentials from the SecretManagement vault for secure email operations.

.VERSION
    1.4.2

.PARAMETER ClientSecret
    The Microsoft Graph ClientSecret to store in the vault.

.PARAMETER SecretName
    Name of the secret in the vault. Defaults to 'MicrosoftGraph-ClientSecret'.

.PARAMETER VaultName
    Name of the SecretManagement vault. Defaults to 'RVToolsVault'.

.PARAMETER Update
    Update existing ClientSecret in the vault.

.PARAMETER Remove
    Remove the ClientSecret from the vault.

.PARAMETER Show
    Display the ClientSecret from the vault (use with caution).

.PARAMETER List
    List Microsoft Graph related secrets in the vault.

.EXAMPLE
    .\Set-MicrosoftGraphCredentials.ps1 -ClientSecret "your-client-secret-value"

.EXAMPLE
    .\Set-MicrosoftGraphCredentials.ps1 -Update -ClientSecret "new-client-secret-value"

.EXAMPLE
    .\Set-MicrosoftGraphCredentials.ps1 -List

.EXAMPLE
    .\Set-MicrosoftGraphCredentials.ps1 -Remove
#>

[CmdletBinding(DefaultParameterSetName='Store')]
param(
    [Parameter(ParameterSetName='Store', Mandatory)] 
    [Parameter(ParameterSetName='Update', Mandatory)] 
    [string] $ClientSecret,
    
    [Parameter()] [string] $SecretName = 'MicrosoftGraph-ClientSecret',
    [Parameter()] [string] $VaultName = 'RVToolsVault',
    
    [Parameter(ParameterSetName='Update')] [switch] $Update,
    [Parameter(ParameterSetName='Remove')] [switch] $Remove,
    [Parameter(ParameterSetName='Show')] [switch] $Show,
    [Parameter(ParameterSetName='List')] [switch] $List
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import RVTools module for common functions
try {
    Import-Module (Join-Path $PSScriptRoot 'RVToolsModule') -Force -ErrorAction Stop
    Write-Verbose "RVToolsModule loaded successfully"
    
    # Use module functions
    function Write-Log {
        param(
            [Parameter(Mandatory)] [string] $Message,
            [ValidateSet('INFO','WARN','ERROR','SUCCESS')] [string] $Level = 'INFO'
        )
        Write-RVToolsLog -Message $Message -Level $Level
    }
} catch {
    Write-Warning "RVToolsModule not available. Using local functions."
    
    # Fallback function
    function Write-Log {
        param(
            [Parameter(Mandatory)] [string] $Message,
            [ValidateSet('INFO','WARN','ERROR','SUCCESS')] [string] $Level = 'INFO'
        )
        $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        Write-Host $line
    }
}

function Test-VaultExists {
    param([string] $VaultName)
    
    if (Get-Command Test-RVToolsVault -ErrorAction SilentlyContinue) {
        return Test-RVToolsVault -VaultName $VaultName
    } else {
        # Fallback method
        $vault = Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue
        return $null -ne $vault
    }
}

function Test-SecretExists {
    param([string] $SecretName, [string] $VaultName)
    try {
        Get-Secret -Name $SecretName -Vault $VaultName -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Validate vault exists
if (-not (Test-VaultExists -VaultName $VaultName)) {
    Write-Log -Level 'ERROR' -Message "Vault '$VaultName' not found. Run Initialize-RVToolsDependencies.ps1 first."
    exit 1
}

try {
    switch ($PSCmdlet.ParameterSetName) {
        'Store' {
            if (Test-SecretExists -SecretName $SecretName -VaultName $VaultName) {
                Write-Log -Level 'ERROR' -Message "Secret '$SecretName' already exists. Use -Update to modify it."
                exit 1
            }
            
            Set-Secret -Name $SecretName -Secret $ClientSecret -Vault $VaultName
            Write-Log -Level 'SUCCESS' -Message "Microsoft Graph ClientSecret stored as '$SecretName' in vault '$VaultName'"
        }
        
        'Update' {
            if (-not (Test-SecretExists -SecretName $SecretName -VaultName $VaultName)) {
                Write-Log -Level 'ERROR' -Message "Secret '$SecretName' not found in vault '$VaultName'."
                exit 1
            }
            
            Set-Secret -Name $SecretName -Secret $ClientSecret -Vault $VaultName
            Write-Log -Level 'SUCCESS' -Message "Microsoft Graph ClientSecret updated for '$SecretName' in vault '$VaultName'"
        }
        
        'Remove' {
            if (-not (Test-SecretExists -SecretName $SecretName -VaultName $VaultName)) {
                Write-Log -Level 'ERROR' -Message "Secret '$SecretName' not found in vault '$VaultName'."
                exit 1
            }
            
            Remove-Secret -Name $SecretName -Vault $VaultName
            Write-Log -Level 'SUCCESS' -Message "Microsoft Graph ClientSecret removed: '$SecretName' from vault '$VaultName'"
        }
        
        'Show' {
            if (-not (Test-SecretExists -SecretName $SecretName -VaultName $VaultName)) {
                Write-Log -Level 'ERROR' -Message "Secret '$SecretName' not found in vault '$VaultName'."
                exit 1
            }
            
            $secret = Get-Secret -Name $SecretName -Vault $VaultName -AsPlainText
            Write-Log -Level 'INFO' -Message "Microsoft Graph ClientSecret for '$SecretName':"
            Write-Host $secret -ForegroundColor Yellow
        }
        
        'List' {
            Write-Log -Level 'INFO' -Message "Microsoft Graph related secrets in vault '$VaultName':"
            $secrets = Get-SecretInfo -Vault $VaultName | Where-Object { $_.Name -like '*Graph*' -or $_.Name -like '*Client*' }
            
            if ($secrets) {
                $secrets | ForEach-Object {
                    Write-Host "  - $($_.Name)" -ForegroundColor Green
                }
            } else {
                Write-Host "  No Microsoft Graph secrets found" -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Log -Level 'ERROR' -Message "Operation failed: $($_.Exception.Message)"
    exit 1
}
