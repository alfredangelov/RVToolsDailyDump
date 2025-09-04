<#
.SYNOPSIS
    Test Microsoft Graph email functionality for RVTools

.DESCRIPTION
    This script tests the Microsoft Graph email functionality without running 
    the full RVTools export. Useful for debugging email configuration issues.

.EXAMPLE
    .\test\Test-RVToolsEmail.ps1

.EXAMPLE
    .\test\Test-RVToolsEmail.ps1 -To "test@domain.com"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'shared/Configuration.psd1'),
    
    [Parameter()]
    [string[]]$To = @(),
    
    [Parameter()]
    [string]$Subject = "RVTools Email Test - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import RVTools module
try {
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $moduleRoot 'RVToolsModule') -Force -ErrorAction Stop
    Write-Host "RVToolsModule loaded successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to load RVToolsModule: $($_.Exception.Message)"
    exit 1
}

# Load configuration
Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Yellow
try {
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $configResult = Import-RVToolsConfiguration -ConfigPath $ConfigPath -ScriptRoot $moduleRoot
    $cfg = $configResult.Configuration
    
    if ($configResult.UsingTemplateConfig) {
        Write-Warning "Using template configuration - some features may not work"
    }
} catch {
    Write-Error "Failed to load configuration: $($_.Exception.Message)"
    exit 1
}

# Check if email is enabled
if (-not $cfg.Email?.Enabled) {
    Write-Error "Email is not enabled in configuration"
    exit 1
}

if ($cfg.Email?.Method -ne 'MicrosoftGraph') {
    Write-Error "This test is only for Microsoft Graph email method. Current method: $($cfg.Email?.Method)"
    exit 1
}

# Set up logging
$moduleRoot = Split-Path $PSScriptRoot -Parent
$logsRoot = Join-Path $moduleRoot ($cfg.LogsFolder ?? 'logs')
New-RVToolsDirectory -Path $logsRoot | Out-Null
$logFile = Join-Path $logsRoot ("EmailTest_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt")

Write-Host "Log file: $logFile" -ForegroundColor Cyan

# Override recipients if provided
$emailCfg = $cfg.Email.Clone()
if ($To.Count -gt 0) {
    $emailCfg.To = $To
    Write-Host "Using override recipients: $($To -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host "Using configured recipients: $($emailCfg.To -join ', ')" -ForegroundColor Yellow
}

# Validate required email configuration
$required = @('TenantId', 'ClientId', 'From', 'To')
$missing = @()

foreach ($prop in $required) {
    if (-not $emailCfg[$prop] -or [string]::IsNullOrWhiteSpace($emailCfg[$prop])) {
        $missing += $prop
    }
}

if ($missing.Count -gt 0) {
    Write-Error "Missing required email configuration: $($missing -join ', ')"
    exit 1
}

# Check for ClientSecret or ClientSecretName
if (-not $emailCfg['ClientSecret'] -and -not $emailCfg['ClientSecretName']) {
    Write-Error "Either ClientSecret or ClientSecretName must be configured"
    exit 1
}

# Create test email body
$body = @"
This is a test email from the RVTools Daily Dump toolkit.

Test Details:
- Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- Test Type: Microsoft Graph Email Functionality
- From: $($emailCfg.From)
- To: $($emailCfg.To -join ', ')
- Script Location: $moduleRoot

If you received this email, the Microsoft Graph email configuration is working correctly.

Configuration Summary:
- Tenant ID: $($emailCfg.TenantId)
- Client ID: $($emailCfg.ClientId)
- Authentication: $(if ($emailCfg.ClientSecretName) { "Vault ($($emailCfg.ClientSecretName))" } else { "Direct Secret" })

Regards,
RVTools Email Test Script
"@

Write-Host "`nTesting Microsoft Graph email functionality..." -ForegroundColor Green
Write-Host "From: $($emailCfg.From)" -ForegroundColor Gray
Write-Host "To: $($emailCfg.To -join ', ')" -ForegroundColor Gray
Write-Host "Subject: $Subject" -ForegroundColor Gray

# Prepare email parameters
$graphParams = @{
    TenantId = $emailCfg.TenantId
    ClientId = $emailCfg.ClientId
    From = $emailCfg.From
    To = $emailCfg.To
    Subject = $Subject
    Body = $body
    LogFile = $logFile
    ConfigLogLevel = 'INFO'
}

# Add ClientSecret or ClientSecretName
if (-not [string]::IsNullOrWhiteSpace($emailCfg['ClientSecret'])) {
    $graphParams.ClientSecret = $emailCfg['ClientSecret']
    Write-Host "Using direct ClientSecret" -ForegroundColor Gray
} elseif (-not [string]::IsNullOrWhiteSpace($emailCfg['ClientSecretName'])) {
    $graphParams.ClientSecretName = $emailCfg['ClientSecretName']
    $graphParams.VaultName = $cfg.Auth.DefaultVault ?? 'RVToolsVault'
    Write-Host "Using ClientSecret from vault: $($emailCfg['ClientSecretName'])" -ForegroundColor Gray
}

# Test the email functionality
try {
    Write-Host "`nSending test email..." -ForegroundColor Yellow
    
    # Import the private function directly since it's not exported
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $moduleRoot 'RVToolsModule\Private\Send-RVToolsGraphEmail.ps1')
    
    $success = Send-RVToolsGraphEmail @graphParams
    
    if ($success) {
        Write-Host "`n✅ SUCCESS: Test email sent successfully!" -ForegroundColor Green
        Write-Host "Check your inbox for the test message." -ForegroundColor Green
    } else {
        Write-Host "`n❌ FAILED: Email was not sent successfully" -ForegroundColor Red
        Write-Host "Check the log file for details: $logFile" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "`n❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check the log file for details: $logFile" -ForegroundColor Yellow
}

# Show log content
Write-Host "`nLog file contents:" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
if (Test-Path $logFile) {
    Get-Content $logFile | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
} else {
    Write-Host "No log file was created" -ForegroundColor Yellow
}

Write-Host "`nTest completed. Log saved to: $logFile" -ForegroundColor Cyan
