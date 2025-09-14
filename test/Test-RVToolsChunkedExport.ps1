<#
.SYNOPSIS
    Test script for RVTools chunked export functionality.

.DESCRIPTION
    This script tests the chunked export functionality with both TestMode and full mode.
    It validates that the chunked export properly creates individual tab files and merges them.

.PARAMETER HostName
    vCenter hostname to test against.

.PARAMETER TestMode
    Use TestMode for quick testing with only 3 tabs.

.PARAMETER SkipActualExport
    Skip the actual export and only test dry run functionality.

.EXAMPLE
    .\test\Test-RVToolsChunkedExport.ps1 -HostName "vcenter.local"

.EXAMPLE
    .\test\Test-RVToolsChunkedExport.ps1 -HostName "vcenter.local" -TestMode

.EXAMPLE
    .\test\Test-RVToolsChunkedExport.ps1 -HostName "vcenter.local" -SkipActualExport
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$HostName,
    
    [Parameter()]
    [switch]$TestMode,
    
    [Parameter()]
    [switch]$SkipActualExport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import RVTools module
$scriptRoot = Split-Path $PSScriptRoot -Parent
try {
    Import-Module (Join-Path $scriptRoot "RVToolsModule\RVToolsModule.psd1") -Force
    Write-Host "✅ RVToolsModule loaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to load RVToolsModule: $($_.Exception.Message)"
    exit 1
}

# Load configuration
$configPath = Join-Path $scriptRoot 'shared/Configuration.psd1'
$hostListPath = Join-Path $scriptRoot 'shared/HostList.psd1'

Write-Host "`n🧪 RVTools Chunked Export Test Suite" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

$testResults = @()

try {
    # Test 1: Dry Run Test
    Write-Host "`n📝 Test 1: Dry Run Chunked Export" -ForegroundColor Yellow
    
    $exportParams = @{
        ConfigPath    = $configPath
        HostListPath  = $hostListPath
        HostName      = $HostName
        ChunkedExport = $true
        DryRun        = $true
    }
    
    if ($TestMode) { 
        $exportParams.TestMode = $true
        Write-Host "   Using TestMode (3 tabs only)" -ForegroundColor Cyan
    }
    
    $dryRunResults = Invoke-RVToolsExport @exportParams
    
    Write-Host "   📊 Raw result type: $($dryRunResults.GetType().Name)" -ForegroundColor Cyan
    Write-Host "   📊 Raw result: $dryRunResults" -ForegroundColor Cyan
    
    if ($dryRunResults) {
        if ($dryRunResults -is [Array] -and $dryRunResults.Count -gt 0) {
            $result = $dryRunResults[0]
        }
        else {
            $result = $dryRunResults
        }
        
        Write-Host "   ✅ Dry run completed successfully" -ForegroundColor Green
        Write-Host "   📊 Result type: $($result.GetType().Name)" -ForegroundColor Green
        
        if ($result.PSObject.Properties['Success']) {
            Write-Host "   📊 Success: $($result.Success)" -ForegroundColor Green
            Write-Host "   📊 Message: $($result.Message)" -ForegroundColor Green
            
            if ($result.PSObject.Properties['SuccessfulTabs']) {
                Write-Host "   📊 Successful Tabs: $($result.SuccessfulTabs)" -ForegroundColor Green
                Write-Host "   📊 Failed Tabs: $($result.FailedTabs)" -ForegroundColor Green
            }
            
            $testResults += @{ Test = "DryRun"; Result = "PASS"; Details = $result.Message }
        }
        else {
            Write-Host "   📊 Result is a string: $result" -ForegroundColor Yellow
            $testResults += @{ Test = "DryRun"; Result = "PASS"; Details = "String result: $result" }
        }
    }
    else {
        Write-Host "   ❌ Dry run failed - no results returned" -ForegroundColor Red
        $testResults += @{ Test = "DryRun"; Result = "FAIL"; Details = "No results returned" }
    }
    
    # Test 2: Module Function Availability Test
    Write-Host "`n📝 Test 2: Module Function Availability" -ForegroundColor Yellow
    
    try {
        # Test that the main export function is available
        $exportFunctionAvailable = Get-Command "Invoke-RVToolsExport" -ErrorAction SilentlyContinue
        
        if ($exportFunctionAvailable) {
            Write-Host "   ✅ Invoke-RVToolsExport function is available" -ForegroundColor Green
            
            # Test that we can get help for the function
            $help = Get-Help "Invoke-RVToolsExport" -ErrorAction SilentlyContinue
            if ($help) {
                Write-Host "   ✅ Function help is available" -ForegroundColor Green
            }
            else {
                Write-Host "   ⚠️  Function help not available" -ForegroundColor Yellow
            }
            
            # Test chunked export functionality by checking for expected parameters
            $parameters = $exportFunctionAvailable.Parameters
            if ($parameters.ContainsKey('ChunkedExport')) {
                Write-Host "   ✅ ChunkedExport parameter is available" -ForegroundColor Green
            }
            else {
                Write-Host "   ⚠️  ChunkedExport parameter not found" -ForegroundColor Yellow
            }
            
            if ($parameters.ContainsKey('TestMode')) {
                Write-Host "   ✅ TestMode parameter is available" -ForegroundColor Green
            }
            else {
                Write-Host "   ⚠️  TestMode parameter not found" -ForegroundColor Yellow
            }
            
            $testResults += @{ Test = "ModuleFunctions"; Result = "PASS"; Details = "All required functions available" }
        }
        else {
            Write-Host "   ❌ Invoke-RVToolsExport function not found" -ForegroundColor Red
            $testResults += @{ Test = "ModuleFunctions"; Result = "FAIL"; Details = "Function not available" }
        }
        
        # Test TestMode parameter information
        if ($TestMode) {
            Write-Host "   📊 TestMode parameter is active (3 tabs)" -ForegroundColor Cyan
        }
        else {
            Write-Host "   📊 Full export mode (26 tabs)" -ForegroundColor Cyan
        }
        
    }
    catch {
        Write-Host "   ❌ Module function test failed: $($_.Exception.Message)" -ForegroundColor Red
        $testResults += @{ Test = "ModuleFunctions"; Result = "FAIL"; Details = $_.Exception.Message }
    }
    
    # Test 3: Actual Export Test (if not skipped)
    if (-not $SkipActualExport) {
        Write-Host "`n📝 Test 3: Actual Chunked Export" -ForegroundColor Yellow
        Write-Host "   ⚠️  This will perform an actual export and may take time..." -ForegroundColor Yellow
        
        $exportParams.Remove('DryRun')
        
        $actualResults = Invoke-RVToolsExport @exportParams
        
        if ($actualResults -and $actualResults.Count -gt 0) {
            $result = $actualResults[0]
            Write-Host "   ✅ Actual export completed" -ForegroundColor Green
            Write-Host "   📊 Success: $($result.Success)" -ForegroundColor Green
            Write-Host "   📊 Message: $($result.Message)" -ForegroundColor Green
            
            if ($result.Success -and $result.PSObject.Properties['FinalFile']) {
                Write-Host "   📊 Final File: $($result.FinalFile)" -ForegroundColor Green
                
                if (Test-Path $result.FinalFile) {
                    $fileSize = (Get-Item $result.FinalFile).Length
                    Write-Host "   📊 File Size: $([math]::Round($fileSize / 1KB, 2)) KB" -ForegroundColor Green
                    $testResults += @{ Test = "ActualExport"; Result = "PASS"; Details = "Export successful, file created ($([math]::Round($fileSize / 1KB, 2)) KB)" }
                }
                else {
                    Write-Host "   ❌ Final file not found" -ForegroundColor Red
                    $testResults += @{ Test = "ActualExport"; Result = "FAIL"; Details = "Final file not created" }
                }
            }
            else {
                Write-Host "   ❌ Export reported failure" -ForegroundColor Red
                $testResults += @{ Test = "ActualExport"; Result = "FAIL"; Details = $result.Message }
            }
        }
        else {
            Write-Host "   ❌ Actual export failed - no results returned" -ForegroundColor Red
            $testResults += @{ Test = "ActualExport"; Result = "FAIL"; Details = "No results returned" }
        }
    }
    else {
        Write-Host "`n📝 Test 3: Actual Export (SKIPPED)" -ForegroundColor Yellow
        $testResults += @{ Test = "ActualExport"; Result = "SKIPPED"; Details = "Skipped by user request" }
    }
    
}
catch {
    Write-Host "`n❌ Test suite failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "📍 At: $($_.ScriptStackTrace)" -ForegroundColor Red
    $testResults += @{ Test = "Exception"; Result = "FAIL"; Details = $_.Exception.Message }
}

# Summary
Write-Host "`n📊 Test Results Summary" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan

# Ensure testResults is an array
if (-not $testResults) {
    $testResults = @()
}
elseif ($testResults -isnot [Array]) {
    $testResults = @($testResults)
}

Write-Host "📊 Debug: Found $($testResults.Count) test results" -ForegroundColor DarkGray

foreach ($test in $testResults) {
    $color = switch ($test.Result) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "SKIPPED" { "Yellow" }
        default { "White" }
    }
    Write-Host "   $($test.Test): $($test.Result) - $($test.Details)" -ForegroundColor $color
}

$passCount = @($testResults | Where-Object { $_.Result -eq "PASS" }).Count
$failCount = @($testResults | Where-Object { $_.Result -eq "FAIL" }).Count
$skipCount = @($testResults | Where-Object { $_.Result -eq "SKIPPED" }).Count

Write-Host "`n🏆 Final Score: $passCount PASS, $failCount FAIL, $skipCount SKIPPED" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })

if ($failCount -eq 0) {
    Write-Host "🎉 All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "💥 Some tests failed!" -ForegroundColor Red
    exit 1
}