#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fixes RVTools log4net configuration issue.

.DESCRIPTION
    This script fixes the log4net configuration issue in RVTools by adding the missing
    log4net section to the RVTools.exe.config file. This resolves the error:
    "Failed to find configuration section 'log4net' in the application's .config file"

.NOTES
    Author: Alfred Angelov
    Date: 2025-08-30
    Purpose: Fix RVTools log4net configuration
    Requirements: Must be run as Administrator
#>

[CmdletBinding()]
param()

# Check if running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator to modify files in Program Files."
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

$rvToolsPath = "C:\Program Files (x86)\Dell\RVTools"
$configFile = Join-Path $rvToolsPath "RVTools.exe.config"
$backupFile = Join-Path $rvToolsPath "RVTools.exe.config.backup"
$log4netConfigFile = Join-Path $rvToolsPath "log4net.config"

# Verify files exist
if (-not (Test-Path $configFile)) {
    Write-Error "RVTools.exe.config not found at: $configFile"
    exit 1
}

if (-not (Test-Path $log4netConfigFile)) {
    Write-Error "log4net.config not found at: $log4netConfigFile"
    exit 1
}

Write-Host "Fixing RVTools log4net configuration..." -ForegroundColor Cyan

try {
    # Create backup
    Write-Host "  Creating backup of original config..." -NoNewline
    Copy-Item $configFile $backupFile -Force
    Write-Host " Done" -ForegroundColor Green

    # Load the existing configuration and log4net configuration
    Write-Host "  Loading configuration files..." -NoNewline
    [xml]$config = Get-Content $configFile
    [xml]$log4netConfig = Get-Content $log4netConfigFile
    Write-Host " Done" -ForegroundColor Green

    # Check if configSections already exists
    $configSections = $config.configuration.SelectSingleNode("configSections")
    if (-not $configSections) {
        Write-Host "  Creating configSections element..." -NoNewline
        $configSections = $config.CreateElement("configSections")
        $config.configuration.InsertBefore($configSections, $config.configuration.FirstChild) | Out-Null
        Write-Host " Done" -ForegroundColor Green
    }

    # Check if log4net section handler already exists
    $existingSection = $configSections.SelectSingleNode("section[@name='log4net']")
    if (-not $existingSection) {
        Write-Host "  Adding log4net section handler..." -NoNewline
        $sectionElement = $config.CreateElement("section")
        $sectionElement.SetAttribute("name", "log4net")
        $sectionElement.SetAttribute("type", "log4net.Config.Log4NetConfigurationSectionHandler,log4net")
        $configSections.AppendChild($sectionElement) | Out-Null
        Write-Host " Done" -ForegroundColor Green
    } else {
        Write-Host "  log4net section handler already exists" -ForegroundColor Yellow
    }

    # Check if log4net section already exists
    $existingLog4netSection = $config.configuration.SelectSingleNode("log4net")
    
    if ($existingLog4netSection) {
        Write-Host "  log4net section already exists in config file" -ForegroundColor Yellow
    } else {
        # Import the log4net node from the separate config file
        Write-Host "  Adding log4net section to main config..." -NoNewline
        $importedNode = $config.ImportNode($log4netConfig.DocumentElement, $true)
        $config.configuration.AppendChild($importedNode) | Out-Null
        Write-Host " Done" -ForegroundColor Green
        
        # Save the updated configuration
        Write-Host "  Saving updated configuration..." -NoNewline
        $config.Save($configFile)
        Write-Host " Done" -ForegroundColor Green
    }

    Write-Host "`nRVTools log4net configuration fixed successfully!" -ForegroundColor Green
    Write-Host "Backup saved as: $backupFile" -ForegroundColor Gray
    
    Write-Host "`nTesting log4net configuration..." -ForegroundColor Cyan
    
    # Test the configuration by attempting to load it
    try {
        [xml]$testConfig = Get-Content $configFile
        $log4netSection = $testConfig.configuration.SelectSingleNode("log4net")
        
        if ($log4netSection) {
            Write-Host "  log4net section found in configuration" -ForegroundColor Green
            Write-Host "  Configuration file is valid XML" -ForegroundColor Green
            Write-Host "`nRVTools should now work without log4net errors!" -ForegroundColor Green
        } else {
            Write-Host "  log4net section still missing" -ForegroundColor Red
        }
    } catch {
        Write-Host "  Configuration file has XML errors: $($_.Exception.Message)" -ForegroundColor Red
        
        # Restore backup
        Write-Host "  Restoring backup..." -NoNewline
        Copy-Item $backupFile $configFile -Force
        Write-Host " Done" -ForegroundColor Green
        
        throw "Failed to create valid configuration. Backup restored."
    }

} catch {
    Write-Error "Failed to fix log4net configuration: $($_.Exception.Message)"
    
    if (Test-Path $backupFile) {
        Write-Host "Backup available at: $backupFile" -ForegroundColor Yellow
        Write-Host "You can manually restore it if needed." -ForegroundColor Yellow
    }
    
    exit 1
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Try running your RVTools connectivity test again" -ForegroundColor Gray
Write-Host "  2. If issues persist, check the RVTools log at: %LOCALAPPDATA%\RVTools\RVTools.log" -ForegroundColor Gray
Write-Host "  3. The backup file can be restored manually if needed" -ForegroundColor Gray
