<#
.SYNOPSIS
    Debug script to test RVTools export return objects.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$HostName,
    
    [Parameter()]
    [switch]$ChunkedExport,
    
    [Parameter()]
    [switch]$TestMode
)

# Import RVTools module
$scriptRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $scriptRoot "RVToolsModule\RVToolsModule.psd1") -Force

# Load configuration
$configPath = Join-Path $scriptRoot 'shared/Configuration.psd1'
$hostListPath = Join-Path $scriptRoot 'shared/HostList.psd1'

try {
    $testModeText = if ($TestMode) { " with TestMode (3 tabs)" } else { "" }
    $chunkedText = if ($ChunkedExport) { " using ChunkedExport" } else { "" }
    Write-Host "🔍 Testing RVTools export return structure$chunkedText$testModeText..." -ForegroundColor Cyan
    
    # Build parameters for the test
    $exportParams = @{
        ConfigPath   = $configPath
        HostListPath = $hostListPath
        DryRun       = $true
    }
    
    if ($ChunkedExport) { $exportParams.ChunkedExport = $true }
    if ($TestMode) { $exportParams.TestMode = $true }
    
    # Test with dry run to avoid actual export
    $results = Invoke-RVToolsExport @exportParams
    
    Write-Host "📊 Results count: $($results.Count)" -ForegroundColor Green
    
    foreach ($result in $results) {
        Write-Host "🏷️ Result object type: $($result.GetType().Name)" -ForegroundColor Yellow
        Write-Host "📋 Properties:" -ForegroundColor Yellow
        
        $result.PSObject.Properties | ForEach-Object {
            Write-Host "    $($_.Name): $($_.Value)" -ForegroundColor White
        }
        
        Write-Host "✅ Has Success property: $($result.PSObject.Properties['Success'] -ne $null)" -ForegroundColor $(if ($result.PSObject.Properties['Success']) { 'Green' } else { 'Red' })
        
        if ($result.PSObject.Properties['Success']) {
            Write-Host "✅ Success value: $($result.Success)" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Missing Success property!" -ForegroundColor Red
        }
        
        Write-Host "---" -ForegroundColor Gray
    }
    
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "📍 At: $($_.ScriptStackTrace)" -ForegroundColor Red
}