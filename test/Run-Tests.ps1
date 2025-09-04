<#
.SYNOPSIS
    Main test runner for the RVTools Daily Dump toolkit.

.DESCRIPTION
    This script runs all available tests for the RVTools toolkit components,
    including configuration validation, credential management, and password encryption tests.

.VERSION
    1.4.2

.PARAMETER TestSuite
    Specific test suite to run. Options: All, Configuration, Credentials, Encryption, Module, ExcelMerge

.PARAMETER NoCleanup
    Skip cleanup operations (preserve test vaults, files, etc.)

.EXAMPLE
    .\Run-Tests.ps1

.EXAMPLE
    .\Run-Tests.ps1 -TestSuite Configuration

.EXAMPLE
    .\Run-Tests.ps1 -TestSuite Module

.EXAMPLE
    .\Run-Tests.ps1 -TestSuite ExcelMerge

.EXAMPLE
    .\Run-Tests.ps1 -Verbose -NoCleanup
#>

[CmdletBinding()]
param(
    [Parameter()] 
    [ValidateSet('All', 'Configuration', 'Credentials', 'Encryption', 'Module', 'ExcelMerge')]
    [string] $TestSuite = 'All',
    
    [Parameter()] [switch] $NoCleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','FAIL','HEADER')] [string] $Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'FAIL' { 'Red' }
        'ERROR' { 'Red' }
        'WARN' { 'Yellow' }
        'HEADER' { 'Cyan' }
        default { 'White' }
    }
    
    if ($Level -eq 'HEADER') {
        Write-Host ""
        Write-Host "=" * 60 -ForegroundColor $color
        Write-Host "  $Message" -ForegroundColor $color
        Write-Host "=" * 60 -ForegroundColor $color
    } else {
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

function Invoke-TestScript {
    param(
        [Parameter(Mandatory)] [string] $ScriptPath,
        [Parameter(Mandatory)] [string] $TestName,
        [Parameter()] [hashtable] $Parameters = @{},
        [Parameter()] [switch] $IsPester
    )
    
    Write-Log -Level 'INFO' -Message "Running: $TestName"
    
    try {
        if (-not (Test-Path $ScriptPath)) {
            Write-Log -Level 'FAIL' -Message "Test script not found: $ScriptPath"
            return $false
        }
        
        $startTime = Get-Date
        
        if ($IsPester) {
            # Handle Pester tests
            try {
                $pesterModule = Get-Module Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
                if (-not $pesterModule) {
                    Write-Log -Level 'WARN' -Message "Pester module not found. Skipping Pester tests."
                    return $true  # Don't fail the overall test suite
                }
                
                Import-Module Pester -Force
                
                $config = New-PesterConfiguration
                $config.Run.Path = $ScriptPath
                $config.Output.Verbosity = 'Normal'
                $config.Run.PassThru = $true
                
                $result = Invoke-Pester -Configuration $config
                
                $duration = (Get-Date) - $startTime
                
                if ($result.FailedCount -eq 0) {
                    Write-Log -Level 'SUCCESS' -Message "$TestName completed successfully - $($result.PassedCount)/$($result.TotalCount) tests passed (Duration: $($duration.TotalSeconds.ToString('F1'))s)"
                    return $true
                } else {
                    Write-Log -Level 'FAIL' -Message "$TestName failed - $($result.FailedCount) out of $($result.TotalCount) tests failed (Duration: $($duration.TotalSeconds.ToString('F1'))s)"
                    return $false
                }
                
            } catch {
                Write-Log -Level 'ERROR' -Message "Pester execution failed: $($_.Exception.Message)"
                return $false
            }
        } else {
            # Handle regular PowerShell tests
            # Build parameter string for splatting
            $paramString = ""
            if ($Parameters.Count -gt 0) {
                $paramArray = @()
                foreach ($key in $Parameters.Keys) {
                    $value = $Parameters[$key]
                    if ($value -is [bool]) {
                        if ($value) {
                            $paramArray += "-$key"
                        } else {
                            $paramArray += "-$key" + ':$false'
                        }
                    } else {
                        $paramArray += "-$key `"$value`""
                    }
                }
                $paramString = $paramArray -join ' '
            }
            
            # Execute the test script
            $result = if ($paramString) {
                Invoke-Expression "& `"$ScriptPath`" $paramString"
            } else {
                & $ScriptPath
            }
            
            $duration = (Get-Date) - $startTime
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -eq 0 -or $result -eq $true) {
                Write-Log -Level 'SUCCESS' -Message "$TestName completed successfully (Duration: $($duration.TotalSeconds.ToString('F1'))s)"
                return $true
            } else {
                Write-Log -Level 'FAIL' -Message "$TestName failed (Exit Code: $exitCode, Duration: $($duration.TotalSeconds.ToString('F1'))s)"
                return $false
            }
        }
    } catch {
        Write-Log -Level 'ERROR' -Message "$TestName threw exception: $($_.Exception.Message)"
        return $false
    }
}

function Get-TestEnvironmentInfo {
    Write-Log -Level 'HEADER' -Message "Test Environment Information"
    
    try {
        Write-Log -Level 'INFO' -Message "PowerShell Version: $($PSVersionTable.PSVersion)"
        Write-Log -Level 'INFO' -Message "OS: $($PSVersionTable.OS)"
        Write-Log -Level 'INFO' -Message "Platform: $($PSVersionTable.Platform)"
        Write-Log -Level 'INFO' -Message "Current User: $env:USERNAME"
        Write-Log -Level 'INFO' -Message "Test Directory: $PSScriptRoot"
        
        # Check for required modules
        $requiredModules = @(
            'Microsoft.PowerShell.SecretManagement',
            'Microsoft.PowerShell.SecretStore'
        )
        
        foreach ($module in $requiredModules) {
            $moduleInfo = Get-Module -Name $module -ListAvailable
            if ($moduleInfo) {
                Write-Log -Level 'SUCCESS' -Message "Module available: $module ($($moduleInfo.Version))"
            } else {
                Write-Log -Level 'WARN' -Message "Module not found: $module"
            }
        }
    } catch {
        Write-Log -Level 'ERROR' -Message "Failed to gather environment info: $($_.Exception.Message)"
    }
}

# Main test execution
Write-Log -Level 'HEADER' -Message "RVTools Daily Dump - Test Suite Runner"

$startTime = Get-Date
$testResults = @()
$testDirectory = $PSScriptRoot
$cleanup = -not $NoCleanup

# Display environment information
Get-TestEnvironmentInfo

# Define available tests
$availableTests = @{
    'Configuration' = @{
        Script = Join-Path $testDirectory 'Test-Configuration.ps1'
        Name = 'Configuration & Host List Tests'
        Parameters = @{}
    }
    'Credentials' = @{
        Script = Join-Path $testDirectory 'Test-Credentials.ps1'
        Name = 'Credential Management Tests'
        Parameters = @{
            TestVault = 'RVToolsTestSuite'
            CleanupAfter = $cleanup
        }
    }
    'Encryption' = @{
        Script = Join-Path $testDirectory 'Test-RVToolsPasswordEncryption.ps1'
        Name = 'Password Encryption Tests'
        Parameters = @{}
    }
    'Module' = @{
        Script = Join-Path $testDirectory 'RVToolsModule.Tests.ps1'
        Name = 'RVToolsModule Pester Tests'
        Parameters = @{}
        IsPester = $true
    }
    'ExcelMerge' = @{
        Script = Join-Path $testDirectory 'Test-RVToolsExcelMerge.ps1'
        Name = 'Excel Merge Functionality Tests'
        Parameters = @{
            QuickTest = $true
        }
    }
}

# Determine which tests to run
$testsToRun = switch ($TestSuite) {
    'All' { $availableTests.Keys }
    'Configuration' { @('Configuration') }
    'Credentials' { @('Credentials') }
    'Encryption' { @('Encryption') }
    'Module' { @('Module') }
    'ExcelMerge' { @('ExcelMerge') }
}

Write-Log -Level 'HEADER' -Message "Running Test Suite: $TestSuite"

# Execute selected tests
foreach ($testKey in $testsToRun) {
    $test = $availableTests[$testKey]
    $isPesterTest = $test.ContainsKey('IsPester') -and $test.IsPester
    $result = Invoke-TestScript -ScriptPath $test.Script -TestName $test.Name -Parameters $test.Parameters -IsPester:$isPesterTest
    
    $testResults += @{
        Name = $test.Name
        Result = $result
        Key = $testKey
    }
}

# Generate summary report
Write-Log -Level 'HEADER' -Message "Test Suite Summary"

$totalDuration = (Get-Date) - $startTime
$passedTests = ($testResults | Where-Object { $_.Result -eq $true }).Count
$totalTests = $testResults.Count

Write-Log -Level 'INFO' -Message "Total Tests: $totalTests"
Write-Log -Level 'INFO' -Message "Passed: $passedTests"
Write-Log -Level 'INFO' -Message "Failed: $($totalTests - $passedTests)"
Write-Log -Level 'INFO' -Message "Duration: $($totalDuration.TotalSeconds.ToString('F1')) seconds"

# Detailed results
Write-Log -Level 'INFO' -Message " "
Write-Log -Level 'INFO' -Message "Detailed Results:"
foreach ($result in $testResults) {
    $status = if ($result.Result) { 'PASS' } else { 'FAIL' }
    $statusColor = if ($result.Result) { 'SUCCESS' } else { 'FAIL' }
    Write-Log -Level $statusColor -Message "  [$status] $($result.Name)"
}

# Final result
if ($passedTests -eq $totalTests) {
    Write-Log -Level 'SUCCESS' -Message "All tests passed! ✅"
    exit 0
} else {
    Write-Log -Level 'FAIL' -Message "Some tests failed! ❌"
    exit 1
}
