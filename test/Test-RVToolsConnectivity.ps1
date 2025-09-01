#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests RVTools connectivity and credential validation for all hosts in HostList.psd1.

.DESCRIPTION
    This script validates stored credentials from the SecretManagement vault and tests
    basic connectivity to vCenter hosts using RVTools. It performs credential retrieval
    testing without full export operations to quickly identify connection issues.

.PARAMETER ConfigPath
    Path to configuration file (Configuration.psd1).

.PARAMETER HostListPath
    Path to host list file (HostList.psd1).

.PARAMETER TestType
    Type of connectivity test to perform:
    - 'CredentialOnly': Only test credential retrieval from vault
    - 'QuickConnect': Test credential + basic RVTools connection (recommended)
    - 'FullValidation': Test credential + vLicense single-tab export (comprehensive)

.PARAMETER HostFilter
    Optional filter to test specific hosts (supports wildcards).

.EXAMPLE
    .\Test-RVToolsConnectivity.ps1
    Test all hosts with quick connection validation.

.EXAMPLE
    .\Test-RVToolsConnectivity.ps1 -TestType CredentialOnly
    Only validate credential retrieval from vault.

.EXAMPLE
    .\Test-RVToolsConnectivity.ps1 -HostFilter "*contorso*"
    Test only hosts matching the filter pattern.

.NOTES
    Author: Alfred Angelov
    Date: 2025-08-30
    Purpose: Validate RVTools connectivity and troubleshoot connection issues
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})]
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..' 'shared' 'Configuration.psd1'),
    
    [Parameter()]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})]
    [string]$HostListPath = (Join-Path $PSScriptRoot '..' 'shared' 'HostList.psd1'),
    
    [Parameter()]
    [ValidateSet('CredentialOnly', 'QuickConnect', 'FullValidation')]
    [string]$TestType = 'QuickConnect',
    
    [Parameter()]
    [string]$HostFilter = '*'
)

# Import required modules
$ModulePath = Join-Path $PSScriptRoot '..' 'RVToolsModule' 'RVToolsModule.psd1'
if (-not (Test-Path $ModulePath)) {
    Write-Error "RVToolsModule not found at: $ModulePath"
    exit 1
}

try {
    Import-Module $ModulePath -Force -ErrorAction Stop
    Write-Host "✓ RVToolsModule imported successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to import RVToolsModule: $($_.Exception.Message)"
    exit 1
}

# Load configuration and host list
try {
    $result = Import-RVToolsConfiguration -ConfigPath $ConfigPath -HostListPath $HostListPath
    $config = $result.Configuration
    $hostList = $result.HostList
    Write-Host "✓ Configuration loaded successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to load configuration: $($_.Exception.Message)"
    exit 1
}

# Test vault availability
try {
    $vaultName = $config.Auth.DefaultVault
    if ([string]::IsNullOrWhiteSpace($vaultName)) {
        Write-Warning "✗ No vault name configured in Auth.DefaultVault"
    } else {
        $vaultTest = Test-RVToolsVault -VaultName $vaultName
        if ($vaultTest) {
            Write-Host "✓ SecretManagement vault '$vaultName' is available" -ForegroundColor Green
        } else {
            Write-Warning "✗ SecretManagement vault '$vaultName' is not available"
        }
    }
} catch {
    Write-Warning "✗ Failed to test vault: $($_.Exception.Message)"
}

# Filter hosts if specified
$filteredHostConfigs = $hostList.Hosts | Where-Object { $_.Name -like $HostFilter }
if (-not $filteredHostConfigs) {
    Write-Error "No hosts match the filter: $HostFilter"
    exit 1
}

Write-Host "`n🔍 Testing connectivity for $($filteredHostConfigs.Count) host(s) with test type: $TestType" -ForegroundColor Cyan
Write-Host "=" * 80

$results = @() # Initialize results array

foreach ($hostConfig in $filteredHostConfigs) {
    $hostName = $hostConfig.Name
    $username = if ($hostConfig.Username) { $hostConfig.Username } else { $config.Auth.Username }
    $exportMode = if ($hostConfig.ExportMode) { $hostConfig.ExportMode } else { 'Normal' }
    
    Write-Host "`n📡 Testing: $hostName (User: $username, Mode: $exportMode)" -ForegroundColor Yellow
    Write-Host "-" * 60
    
    $testResult = @{
        HostName = $hostName
        Username = $username
        ExportMode = $exportMode
        CredentialTest = $false
        ConnectionTest = $false
        ErrorMessage = $null
        TestDetails = @{}
    }
    
    try {
        # Test 1: Credential Retrieval
        Write-Host "  🔑 Testing credential retrieval..." -NoNewline
        $credential = Get-RVToolsCredentialFromVault -HostName $hostName -Username $username -VaultName $vaultName
        
        if ($credential -and $credential.Password) {
            $testResult.CredentialTest = $true
            $testResult.TestDetails.SecretName = Get-RVToolsSecretName -HostName $hostName -Username $username -Pattern $config.Auth.SecretNamePattern
            Write-Host " ✓ SUCCESS" -ForegroundColor Green
            Write-Host "    └─ Secret: $($testResult.TestDetails.SecretName)" -ForegroundColor Gray
        } else {
            Write-Host " ✗ FAILED (No credential retrieved)" -ForegroundColor Red
            $testResult.ErrorMessage = "Failed to retrieve credential from vault"
            $results += $testResult
            continue
        }
        
        # Stop here if only testing credentials
        if ($TestType -eq 'CredentialOnly') {
            $results += $testResult
            continue
        }
        
        # Test 2: Basic RVTools Connection
        Write-Host "  🌐 Testing RVTools connection..." -NoNewline
        
        # Create a temporary test using RVTools with minimal operation
        $rvToolsPath = Resolve-RVToolsPath -Path $config.RVToolsPath -ScriptRoot (Split-Path $ConfigPath -Parent)
        
        if (-not (Test-Path $rvToolsPath)) {
            Write-Host " ✗ FAILED (RVTools not found)" -ForegroundColor Red
            $testResult.ErrorMessage = "RVTools executable not found at: $rvToolsPath"
            $results += $testResult
            continue
        }
        
        $testResult.TestDetails.RVToolsPath = $rvToolsPath
        
        # Test connection by attempting to login (without export)
        $encryptedPassword = Get-RVToolsEncryptedPassword -Credential $credential
        
        if ($TestType -eq 'QuickConnect') {
            # Quick test: attempt to connect and immediately disconnect
            $tempStdOut = New-TemporaryFile
            $tempStdErr = New-TemporaryFile
            
            $testArgs = @(
                '-c', 'ExportAll2xlsx'  # Use proper command structure
                '-s', $hostName
                '-u', $username
                '-p', $encryptedPassword  # Use encrypted password with -p flag
            )
            
            try {
                # Change to RVTools directory (as recommended by Dell)
                $originalLocation = Get-Location
                Set-Location (Split-Path $rvToolsPath -Parent)
                
                $process = Start-Process -FilePath $rvToolsPath -ArgumentList $testArgs -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $tempStdOut.FullName -RedirectStandardError $tempStdErr.FullName
                
                # Read output for debugging
                $stdOut = if (Test-Path $tempStdOut.FullName) { Get-Content $tempStdOut.FullName -Raw } else { "" }
                $stdErr = if (Test-Path $tempStdErr.FullName) { Get-Content $tempStdErr.FullName -Raw } else { "" }
                
                $testResult.TestDetails.RVToolsStdOut = $stdOut
                $testResult.TestDetails.RVToolsStdErr = $stdErr
                $testResult.TestDetails.ExitCode = $process.ExitCode
                
                # Restore original location
                Set-Location $originalLocation
                
                if ($process.ExitCode -eq 0) {
                    $testResult.ConnectionTest = $true
                    Write-Host " ✓ SUCCESS" -ForegroundColor Green
                    Write-Host "    └─ RVTools connected successfully" -ForegroundColor Gray
                } else {
                    Write-Host " ✗ FAILED (Exit code: $($process.ExitCode))" -ForegroundColor Red
                    $testResult.ErrorMessage = "RVTools connection failed with exit code: $($process.ExitCode)"
                    if ($stdErr) {
                        $testResult.ErrorMessage += " - Error: $($stdErr.Trim())"
                        Write-Host "    └─ RVTools Error: $($stdErr.Trim())" -ForegroundColor Red
                    }
                }
                
                # Clean up temp files
                Remove-Item $tempStdOut.FullName, $tempStdErr.FullName -Force -ErrorAction SilentlyContinue
                
            } catch {
                Set-Location $originalLocation -ErrorAction SilentlyContinue
                Write-Host " ✗ FAILED (Exception)" -ForegroundColor Red
                $testResult.ErrorMessage = "RVTools connection exception: $($_.Exception.Message)"
                Remove-Item $tempStdOut.FullName, $tempStdErr.FullName -Force -ErrorAction SilentlyContinue
            }
        } elseif ($TestType -eq 'FullValidation') {
            # Full test: attempt vLicense single-tab export
            Write-Host "    └─ Using vLicense single-tab export for validation" -ForegroundColor Gray
            
            try {
                # Direct RVTools call for vLicense export
                $tempDir = [System.IO.Path]::GetTempPath()
                $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                $testFileName = "connectivity-test-$($hostName.Replace('.', '_'))-$timestamp-vLicense.xlsx"
                $testFilePath = Join-Path $tempDir $testFileName
                
                $encryptedPassword = Get-RVToolsEncryptedPassword -Credential $credential
                
                # Use vLicense export command
                $testArgs = @(
                    '-c', 'ExportvLicense2xlsx'
                    '-s', $hostName
                    '-u', $username
                    '-p', $encryptedPassword
                    '-d', $tempDir
                    '-f', $testFileName
                )
                
                $tempStdOut = New-TemporaryFile
                $tempStdErr = New-TemporaryFile
                
                # Change to RVTools directory
                $originalLocation = Get-Location
                Set-Location (Split-Path $rvToolsPath -Parent)
                
                $process = Start-Process -FilePath $rvToolsPath -ArgumentList $testArgs -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $tempStdOut.FullName -RedirectStandardError $tempStdErr.FullName
                
                # Read output for debugging
                $stdOut = if (Test-Path $tempStdOut.FullName) { Get-Content $tempStdOut.FullName -Raw } else { "" }
                $stdErr = if (Test-Path $tempStdErr.FullName) { Get-Content $tempStdErr.FullName -Raw } else { "" }
                
                # Restore location
                Set-Location $originalLocation
                
                $testResult.TestDetails.ExitCode = $process.ExitCode
                $testResult.TestDetails.RVToolsStdOut = $stdOut
                $testResult.TestDetails.RVToolsStdErr = $stdErr
                
                if ($process.ExitCode -eq 0 -and (Test-Path $testFilePath)) {
                    $testResult.ConnectionTest = $true
                    $testResult.TestDetails.ExportFile = $testFilePath
                    Write-Host " ✓ SUCCESS" -ForegroundColor Green
                    Write-Host "    └─ vLicense export completed: $testFileName" -ForegroundColor Gray
                    
                    # Clean up test file
                    Remove-Item $testFilePath -Force -ErrorAction SilentlyContinue
                } else {
                    Write-Host " ✗ FAILED (Exit code: $($process.ExitCode))" -ForegroundColor Red
                    $testResult.ErrorMessage = "vLicense export failed with exit code: $($process.ExitCode)"
                    if ($stdErr) {
                        $testResult.ErrorMessage += " - Error: $($stdErr.Trim())"
                        Write-Host "    └─ RVTools Error: $($stdErr.Trim())" -ForegroundColor Red
                    }
                }
                
                # Clean up temp files
                Remove-Item $tempStdOut.FullName, $tempStdErr.FullName -Force -ErrorAction SilentlyContinue
                
            } catch {
                Set-Location $originalLocation -ErrorAction SilentlyContinue
                Write-Host " ✗ FAILED (Exception)" -ForegroundColor Red
                $testResult.ErrorMessage = "vLicense export test exception: $($_.Exception.Message)"
                Remove-Item $tempStdOut.FullName, $tempStdErr.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        
    } catch {
        Write-Host " ✗ FAILED (Exception)" -ForegroundColor Red
        $testResult.ErrorMessage = "Test exception: $($_.Exception.Message)"
    }
    
    $results += $testResult
}

# Summary Report
Write-Host "`n📊 CONNECTIVITY TEST SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 80

$successCount = ($results | Where-Object { $_.CredentialTest -and ($TestType -eq 'CredentialOnly' -or $_.ConnectionTest) }).Count
$totalCount = $results.Count

Write-Host "Overall Status: " -NoNewline
if ($successCount -eq $totalCount) {
    Write-Host "✓ ALL TESTS PASSED ($successCount/$totalCount)" -ForegroundColor Green
} elseif ($successCount -gt 0) {
    Write-Host "⚠ PARTIAL SUCCESS ($successCount/$totalCount)" -ForegroundColor Yellow
} else {
    Write-Host "✗ ALL TESTS FAILED ($successCount/$totalCount)" -ForegroundColor Red
}

Write-Host "`nDetailed Results:" -ForegroundColor Cyan

foreach ($result in $results) {
    $status = if ($result.CredentialTest -and ($TestType -eq 'CredentialOnly' -or $result.ConnectionTest)) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($status -eq "✓ PASS") { "Green" } else { "Red" }
    
    Write-Host "  $($result.HostName) ($($result.Username)): " -NoNewline
    Write-Host $status -ForegroundColor $color
    
    if ($result.CredentialTest) {
        Write-Host "    └─ Credential: ✓ Retrieved from vault" -ForegroundColor Gray
    } else {
        Write-Host "    └─ Credential: ✗ Failed to retrieve" -ForegroundColor Gray
    }
    
    if ($TestType -ne 'CredentialOnly') {
        if ($result.ConnectionTest) {
            Write-Host "    └─ Connection: ✓ RVTools connected successfully" -ForegroundColor Gray
        } else {
            Write-Host "    └─ Connection: ✗ Failed to connect" -ForegroundColor Gray
        }
    }
    
    if ($result.ErrorMessage) {
        Write-Host "    └─ Error: $($result.ErrorMessage)" -ForegroundColor Red
    }
}

# Recommendations
Write-Host "`n💡 RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host "=" * 80

$failedCredentials = $results | Where-Object { -not $_.CredentialTest }
$failedConnections = $results | Where-Object { $_.CredentialTest -and -not $_.ConnectionTest -and $TestType -ne 'CredentialOnly' }

if ($failedCredentials) {
    Write-Host "🔑 Credential Issues:" -ForegroundColor Yellow
    foreach ($failed in $failedCredentials) {
        Write-Host "  • $($failed.HostName): Use Set-RVToolsCredentials.ps1 to store credentials" -ForegroundColor Gray
    }
}

if ($failedConnections) {
    Write-Host "🌐 Connection Issues:" -ForegroundColor Yellow
    foreach ($failed in $failedConnections) {
        Write-Host "  • $($failed.HostName): Check network connectivity, vCenter status, and firewall rules" -ForegroundColor Gray
    }
}

if ($successCount -eq $totalCount) {
    Write-Host "🎉 All connectivity tests passed! Your RVTools setup is ready for production use." -ForegroundColor Green
}

# Exit with appropriate code
exit ($totalCount - $successCount)
