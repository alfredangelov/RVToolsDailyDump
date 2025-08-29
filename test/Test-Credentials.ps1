<#
.SYNOPSIS
    Test the credential management functionality.

.DESCRIPTION
    This script tests the SecretManagement vault operations, credential storage/retrieval,
    and credential validation functionality of the RVTools toolkit.

.VERSION
    1.4.2

.PARAMETER TestVault
    Name of the test vault to create (default: RVToolsTest)

.PARAMETER CleanupAfter
    Remove test vault after testing (default: true)

.EXAMPLE
    .\Test-Credentials.ps1

.EXAMPLE
    .\Test-Credentials.ps1 -TestVault "MyTestVault" -CleanupAfter:$false
#>

[CmdletBinding()]
param(
    [Parameter()] [string] $TestVault = 'RVToolsTest',
    [Parameter()] [bool] $CleanupAfter = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','FAIL')] [string] $Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'FAIL' { 'Red' }
        'ERROR' { 'Red' }
        'WARN' { 'Yellow' }
        default { 'White' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-SecretManagementModule {
    Write-Log -Level 'INFO' -Message "Testing SecretManagement module availability"
    
    try {
        $module = Get-Module -Name Microsoft.PowerShell.SecretManagement -ListAvailable
        if ($module) {
            Write-Log -Level 'SUCCESS' -Message "SecretManagement module found: $($module.Version)"
            Import-Module Microsoft.PowerShell.SecretManagement -Force
            return $true
        } else {
            Write-Log -Level 'FAIL' -Message "SecretManagement module not found"
            return $false
        }
    } catch {
        Write-Log -Level 'ERROR' -Message "Failed to load SecretManagement: $($_.Exception.Message)"
        return $false
    }
}

function Test-VaultOperations {
    param([string] $VaultName)
    
    Write-Log -Level 'INFO' -Message "Testing vault operations with: $VaultName"
    
    try {
        # Check if vault already exists
        $existingVault = Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue
        if ($existingVault) {
            Write-Log -Level 'WARN' -Message "Test vault already exists, removing first"
            Unregister-SecretVault -Name $VaultName -ErrorAction SilentlyContinue
        }
        
        # Register test vault
        Register-SecretVault -Name $VaultName -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault:$false
        Write-Log -Level 'SUCCESS' -Message "Test vault registered successfully"
        
        # Verify vault registration
        $vault = Get-SecretVault -Name $VaultName
        if ($vault) {
            Write-Log -Level 'SUCCESS' -Message "Vault verification successful"
            return $true
        } else {
            Write-Log -Level 'FAIL' -Message "Vault verification failed"
            return $false
        }
    } catch {
        Write-Log -Level 'ERROR' -Message "Vault operations failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-CredentialStorage {
    param([string] $VaultName)
    
    Write-Log -Level 'INFO' -Message "Testing credential storage and retrieval"
    
    try {
        # Test credentials
        $testCredentials = @(
            @{ Name = 'TestHost1'; Username = 'testuser1'; Password = 'TestPassword123!' }
            @{ Name = 'TestHost2'; Username = 'testuser2'; Password = 'AnotherPassword456@' }
        )
        
        foreach ($cred in $testCredentials) {
            $secretName = "RVTools-$($cred.Name)"
            $securePassword = $cred.Password | ConvertTo-SecureString -AsPlainText -Force
            $credObject = [PSCredential]::new($cred.Username, $securePassword)
            
            # Store credential
            Set-Secret -Name $secretName -Secret $credObject -Vault $VaultName
            Write-Log -Level 'SUCCESS' -Message "Stored credential for: $($cred.Name)"
            
            # Retrieve credential
            $retrievedCred = Get-Secret -Name $secretName -Vault $VaultName -AsPlainText:$false
            if ($retrievedCred -and $retrievedCred.UserName -eq $cred.Username) {
                Write-Log -Level 'SUCCESS' -Message "Retrieved credential for: $($cred.Name)"
                
                # Test password retrieval
                $retrievedPassword = $retrievedCred.GetNetworkCredential().Password
                if ($retrievedPassword -eq $cred.Password) {
                    Write-Log -Level 'SUCCESS' -Message "Password verification successful for: $($cred.Name)"
                } else {
                    Write-Log -Level 'FAIL' -Message "Password mismatch for: $($cred.Name)"
                    return $false
                }
            } else {
                Write-Log -Level 'FAIL' -Message "Failed to retrieve credential for: $($cred.Name)"
                return $false
            }
        }
        
        # List all secrets in vault
        $secrets = Get-SecretInfo -Vault $VaultName
        Write-Log -Level 'SUCCESS' -Message "Found $($secrets.Count) secrets in test vault"
        
        return $true
    } catch {
        Write-Log -Level 'ERROR' -Message "Credential storage test failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-CredentialCleanup {
    param([string] $VaultName)
    
    Write-Log -Level 'INFO' -Message "Testing credential cleanup"
    
    try {
        # Remove test secrets
        $secrets = Get-SecretInfo -Vault $VaultName
        foreach ($secret in $secrets) {
            Remove-Secret -Name $secret.Name -Vault $VaultName
            Write-Log -Level 'SUCCESS' -Message "Removed secret: $($secret.Name)"
        }
        
        # Verify cleanup
        $remainingSecrets = Get-SecretInfo -Vault $VaultName
        if ($remainingSecrets.Count -eq 0) {
            Write-Log -Level 'SUCCESS' -Message "All test secrets cleaned up successfully"
            return $true
        } else {
            Write-Log -Level 'WARN' -Message "$($remainingSecrets.Count) secrets remain in vault"
            return $false
        }
    } catch {
        Write-Log -Level 'ERROR' -Message "Credential cleanup failed: $($_.Exception.Message)"
        return $false
    }
}

function Remove-TestVault {
    param([string] $VaultName)
    
    Write-Log -Level 'INFO' -Message "Removing test vault: $VaultName"
    
    try {
        Unregister-SecretVault -Name $VaultName
        Write-Log -Level 'SUCCESS' -Message "Test vault removed successfully"
        return $true
    } catch {
        Write-Log -Level 'ERROR' -Message "Failed to remove test vault: $($_.Exception.Message)"
        return $false
    }
}

# Main test execution
Write-Log -Level 'INFO' -Message "RVTools Credential Management Tests"
Write-Log -Level 'INFO' -Message "====================================="

$testResults = @()

# Test SecretManagement module
$testResults += Test-SecretManagementModule

if ($testResults[-1]) {
    # Test vault operations
    $testResults += Test-VaultOperations -VaultName $TestVault
    
    if ($testResults[-1]) {
        # Test credential storage
        $testResults += Test-CredentialStorage -VaultName $TestVault
        
        # Test credential cleanup
        $testResults += Test-CredentialCleanup -VaultName $TestVault
        
        # Remove test vault if requested
        if ($CleanupAfter) {
            $testResults += Remove-TestVault -VaultName $TestVault
        } else {
            Write-Log -Level 'INFO' -Message "Test vault preserved for manual inspection: $TestVault"
        }
    }
} else {
    Write-Log -Level 'ERROR' -Message "Cannot proceed without SecretManagement module"
}

# Test summary
Write-Log -Level 'INFO' -Message ""
Write-Log -Level 'INFO' -Message "Test Summary"
Write-Log -Level 'INFO' -Message "============"

$passedTests = ($testResults | Where-Object { $_ -eq $true }).Count
$totalTests = $testResults.Count

if ($passedTests -eq $totalTests) {
    Write-Log -Level 'SUCCESS' -Message "All tests passed! ($passedTests/$totalTests)"
    exit 0
} else {
    Write-Log -Level 'FAIL' -Message "Some tests failed! ($passedTests/$totalTests)"
    exit 1
}
