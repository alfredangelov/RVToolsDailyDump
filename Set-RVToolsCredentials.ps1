<#
.SYNOPSIS
    Manage credentials for RVTools hosts using PowerShell SecretManagement.

.DESCRIPTION
    This script helps store, update, and manage credentials for vCenter hosts
    that will be used by RVToolsDump.ps1. Credentials are stored securely
    using PowerShell SecretManagement.

.PARAMETER ConfigPath
    Path to the configuration file. Defaults to shared/Configuration.psd1.

.PARAMETER HostListPath
    Path to the host list file. Defaults to shared/HostList.psd1.

.PARAMETER HostName
    Specific host to manage credentials for. If not specified, processes all hosts.

.PARAMETER Username
    Username for the credential. If not specified, prompts for input.

.PARAMETER UpdateAll
    Update credentials for all hosts in the host list.

.PARAMETER RemoveCredential
    Remove stored credential for the specified host.

.PARAMETER ListCredentials
    List all stored credentials for RVTools hosts.

.EXAMPLE
    .\Set-RVToolsCredentials.ps1 -HostName "vcenter01.contoso.local" -Username "svc_rvtools"

.EXAMPLE
    .\Set-RVToolsCredentials.ps1 -UpdateAll

.EXAMPLE
    .\Set-RVToolsCredentials.ps1 -ListCredentials

.NOTES
    Version: 3.2.0
    Refactored in v2.1.0: Leverages RVToolsModule functions for better code reuse and consistency.
    Enhanced in v1.3.0: Username parameter support for credential removal and improved secret name parsing.
#>

[CmdletBinding(DefaultParameterSetName = 'Single')]
param(
    [Parameter()] [string] $ConfigPath = (Join-Path $PSScriptRoot 'shared/Configuration.psd1'),
    [Parameter()] [string] $HostListPath = (Join-Path $PSScriptRoot 'shared/HostList.psd1'),
    
    [Parameter(ParameterSetName = 'Single', Mandatory)]
    [Parameter(ParameterSetName = 'Remove', Mandatory)]
    [string] $HostName,

    [Parameter(ParameterSetName = 'Single')]
    [Parameter(ParameterSetName = 'Remove')]
    [string] $Username,
    [Parameter(ParameterSetName = 'UpdateAll')] [switch] $UpdateAll,
    [Parameter(ParameterSetName = 'Remove')] [switch] $RemoveCredential,
    [Parameter(ParameterSetName = 'List')] [switch] $ListCredentials
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

function Get-SecretName {
    param(
        [Parameter(Mandatory)] [string] $HostName,
        [Parameter(Mandatory)] [string] $Username,
        [Parameter(Mandatory)] [string] $Pattern
    )
    
    return Get-RVToolsSecretName -HostName $HostName -Username $Username -Pattern $Pattern
}

# Load configuration using module function
try {
    $configResult = Import-RVToolsConfiguration -ConfigPath $ConfigPath -HostListPath $HostListPath -ScriptRoot $PSScriptRoot
    $cfg = $configResult.Configuration
    $vaultName = $cfg.Auth.DefaultVault ?? 'RVToolsVault'
    $secretPattern = $cfg.Auth.SecretNamePattern ?? '{HostName}-{Username}'
} catch {
    Write-Log -Level 'ERROR' -Message "Failed to load configuration: $($_.Exception.Message)"
    exit 1
}

# Test SecretManagement and vault availability
try {
    Import-Module Microsoft.PowerShell.SecretManagement -Force -ErrorAction Stop
    
    $vaultExists = Test-RVToolsVault -VaultName $vaultName
    if (-not $vaultExists) {
        Write-Log -Level 'ERROR' -Message "Vault '$vaultName' not found. Please run Initialize-RVToolsDependencies.ps1 first."
        exit 1
    }
    Write-Log -Level 'INFO' -Message "Using vault: $vaultName"
} catch {
    Write-Log -Level 'ERROR' -Message "SecretManagement not available or vault test failed: $($_.Exception.Message)"
    Write-Log -Level 'ERROR' -Message "Please install Microsoft.PowerShell.SecretManagement module and run Initialize-RVToolsDependencies.ps1"
    exit 1
}

switch ($PSCmdlet.ParameterSetName) {
    'List' {
        Write-Log -Level 'INFO' -Message "Listing stored credentials for vault: $vaultName"
        $secrets = Get-SecretInfo -Vault $vaultName | Where-Object { $_.Name -like "*-*" }
        if ($secrets) {
            foreach ($secret in $secrets) {
                # Split at the last dash
                $lastDash = $secret.Name.LastIndexOf('-')
                if ($lastDash -gt 0) {
                    $hostName = $secret.Name.Substring(0, $lastDash)
                    $user = $secret.Name.Substring($lastDash + 1)
                } else {
                    $hostName = $secret.Name
                    $user = ''
                }
                $lastModified = if ($secret.Metadata -and $secret.Metadata.ContainsKey('LastModified')) { 
                    $secret.Metadata.LastModified 
                } else { 
                    'Unknown' 
                }
                Write-Host "Host: $hostName | Username: $user | Type: $($secret.Type) | Modified: $lastModified"
            }
        } else {
            Write-Log -Level 'WARN' -Message "No credentials found in vault: $vaultName"
        }
    }
    
    'Remove' {
        # Use provided Username, or prompt, or config default
        if (-not $Username) {
            $Username = $cfg.Auth.Username ?? (Read-Host -Prompt "Enter username for $HostName")
        }
        if (-not $Username) {
            Write-Log -Level 'ERROR' -Message "Username is required to remove credential for $HostName"
            return
        }
        $secretName = Get-SecretName -HostName $HostName -Username $Username -Pattern $secretPattern
        try {
            Remove-Secret -Name $secretName -Vault $vaultName -Confirm:$false
            Write-Log -Level 'SUCCESS' -Message "Removed credential for $HostName ($Username)"
        } catch {
            Write-Log -Level 'ERROR' -Message "Failed to remove credential: $($_.Exception.Message)"
        }
    }
    
    'Single' {
        # Ensure we have a username before proceeding
        if (-not $Username) {
            $Username = $cfg.Auth.Username ?? (Read-Host -Prompt "Enter username for $HostName")
        }
        
        # Validate that we now have a username
        if (-not $Username) {
            Write-Log -Level 'ERROR' -Message "Username is required but was not provided"
            return
        }
        
        $secretName = Get-SecretName -HostName $HostName -Username $Username -Pattern $secretPattern
        $credential = Get-Credential -UserName $Username -Message "Enter password for $Username on $HostName"
        
        try {
            Set-Secret -Name $secretName -Secret $credential -Vault $vaultName
            Write-Log -Level 'SUCCESS' -Message "Stored credential for $HostName ($Username)"
        } catch {
            Write-Log -Level 'ERROR' -Message "Failed to store credential: $($_.Exception.Message)"
        }
    }
    
    'UpdateAll' {
        # Use host list from configuration result
        $hostItems = $configResult.HostList?.Hosts
        if (-not $hostItems) { 
            Write-Log -Level 'ERROR' -Message "Host list is empty in '$($configResult.HostListPath)'"
            exit 1
        }
        
        # Normalize host entries using same logic as main script
        $servers = @(
            foreach ($item in $hostItems) {
                switch ($item.GetType().Name) {
                    'String'      { [pscustomobject]@{ Name = $item; Username = $null } }
                    'Hashtable'   { [pscustomobject]@{ Name = $item.Name; Username = $item.Username } }
                    'PSCustomObject' { [pscustomobject]@{ Name = $item.Name; Username = $item.Username } }
                    default       { Write-Warning "Unsupported host list entry type: $($item.GetType().FullName)"; continue }
                }
            }
        ) | Where-Object { $_.Name }
        
        foreach ($server in $servers) {
            $user = $server.Username ?? $cfg.Auth.Username
            if (-not $user) {
                $user = Read-Host -Prompt "Enter username for $($server.Name)"
            }
            
            $secretName = Get-SecretName -HostName $server.Name -Username $user -Pattern $secretPattern
            $credential = Get-Credential -UserName $user -Message "Enter password for $user on $($server.Name)"
            
            try {
                Set-Secret -Name $secretName -Secret $credential -Vault $vaultName
                Write-Log -Level 'SUCCESS' -Message "Stored credential for $($server.Name) ($user)"
            } catch {
                Write-Log -Level 'ERROR' -Message "Failed to store credential for $($server.Name): $($_.Exception.Message)"
            }
        }
    }
}

Write-Log -Level 'INFO' -Message "Credential management complete."
