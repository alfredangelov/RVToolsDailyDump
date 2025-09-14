#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive connectivity and RVTools diagnostic test script.

.DESCRIPTION
    This script performs detailed connectivity and RVTools diagnostics to help
    identify why exports might be failing. It tests network connectivity,
    authentication, and RVTools functionality.

.PARAMETER HostName
    vCenter server hostname to test.

.PARAMETER Credential
    PSCredential object for vCenter authentication (optional).

.PARAMETER RVToolsPath
    Path to RVTools executable (optional, will auto-detect).

.PARAMETER TestExport
    Perform an actual test export (creates a small test file).

.PARAMETER LogFile
    Custom log file path (optional).

.EXAMPLE
    .\Test-RVToolsConnectivity.ps1 -HostName "vcenter.company.com"

.EXAMPLE
    .\Test-RVToolsConnectivity.ps1 -HostName "vcenter.company.com" -TestExport

.EXAMPLE
    $cred = Get-Credential
    .\Test-RVToolsConnectivity.ps1 -HostName "vcenter.company.com" -Credential $cred -TestExport
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$HostName,
    
    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential,
    
    [Parameter()]
    [string]$RVToolsPath,
    
    [Parameter()]
    [switch]$TestExport,
    
    [Parameter()]
    [string]$LogFile
)

# Import required modules
$scriptRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $scriptRoot "RVToolsModule\RVToolsModule.psd1") -Force

function Write-DiagnosticLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','HEADER')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
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
        $logMessage = "[$timestamp] [$Level] $Message"
        Write-Host $logMessage -ForegroundColor $color
        
        if ($LogFile) {
            $logMessage | Out-File $LogFile -Append -Encoding UTF8
        }
    }
}

function Test-NetworkConnectivity {
    param([string]$HostName)
    
    Write-DiagnosticLog -Level 'HEADER' -Message "Network Connectivity Tests"
    
    # DNS Resolution
    try {
        $dnsResult = Resolve-DnsName $HostName -ErrorAction Stop
        Write-DiagnosticLog -Level 'SUCCESS' -Message "✅ DNS Resolution: $HostName resolves to $($dnsResult.IPAddress -join ', ')"
    } catch {
        Write-DiagnosticLog -Level 'ERROR' -Message "❌ DNS Resolution failed: $($_.Exception.Message)"
        return $false
    }
    
    # ICMP Ping
    try {
        $pingResult = Test-Connection $HostName -Count 2 -Quiet
        if ($pingResult) {
            Write-DiagnosticLog -Level 'SUCCESS' -Message "✅ ICMP Ping: $HostName is reachable"
        } else {
            Write-DiagnosticLog -Level 'WARN' -Message "⚠️ ICMP Ping: $HostName is not responding (may be blocked by firewall)"
        }
    } catch {
        Write-DiagnosticLog -Level 'WARN' -Message "⚠️ ICMP Ping failed: $($_.Exception.Message)"
    }
    
    # HTTPS Port Test (443)
    try {
        $httpsTest = Test-NetConnection $HostName -Port 443 -WarningAction SilentlyContinue
        if ($httpsTest.TcpTestSucceeded) {
            Write-DiagnosticLog -Level 'SUCCESS' -Message "✅ HTTPS (443): Connection successful"
            Write-DiagnosticLog -Level 'INFO' -Message "    Remote Address: $($httpsTest.RemoteAddress)"
            Write-DiagnosticLog -Level 'INFO' -Message "    Latency: $($httpsTest.PingReplyDetails.RoundtripTime)ms"
        } else {
            Write-DiagnosticLog -Level 'ERROR' -Message "❌ HTTPS (443): Connection failed"
            return $false
        }
    } catch {
        Write-DiagnosticLog -Level 'ERROR' -Message "❌ HTTPS test failed: $($_.Exception.Message)"
        return $false
    }
    
    # SSL Certificate Test  
    try {
        $webRequest = [Net.WebRequest]::Create("https://$HostName")
        $webRequest.Timeout = 10000
        $webRequest.GetResponse() | Out-Null
        Write-DiagnosticLog -Level 'SUCCESS' -Message "✅ SSL Certificate: Valid and trusted"
    } catch {
        Write-DiagnosticLog -Level 'WARN' -Message "⚠️ SSL Certificate: $($_.Exception.Message)"
    }
    
    return $true
}

function Test-RVToolsInstallation {
    param([string]$RVToolsPath)
    
    Write-DiagnosticLog -Level 'HEADER' -Message "RVTools Installation Check"
    
    # Auto-detect RVTools if not provided
    if (-not $RVToolsPath) {
        $possiblePaths = @(
            "C:\Program Files (x86)\Dell\RVTools\RVTools.exe",
            "C:\Program Files\Dell\RVTools\RVTools.exe",
            "C:\RVTools\RVTools.exe"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $RVToolsPath = $path
                break
            }
        }
    }
    
    if (-not $RVToolsPath -or -not (Test-Path $RVToolsPath)) {
        Write-DiagnosticLog -Level 'ERROR' -Message "❌ RVTools not found at expected locations"
        return $null
    }
    
    Write-DiagnosticLog -Level 'SUCCESS' -Message "✅ RVTools found: $RVToolsPath"
    
    # Get RVTools version
    try {
        $fileInfo = Get-Item $RVToolsPath
        Write-DiagnosticLog -Level 'INFO' -Message "    Version: $($fileInfo.VersionInfo.FileVersion)"
        Write-DiagnosticLog -Level 'INFO' -Message "    Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB"
        Write-DiagnosticLog -Level 'INFO' -Message "    Modified: $($fileInfo.LastWriteTime)"
    } catch {
        Write-DiagnosticLog -Level 'WARN' -Message "⚠️ Could not read RVTools file info: $($_.Exception.Message)"
    }
    
    # Check for log4net.config file (common issue)
    $log4netConfig = Join-Path (Split-Path $RVToolsPath -Parent) "log4net.config"
    if (Test-Path $log4netConfig) {
        Write-DiagnosticLog -Level 'SUCCESS' -Message "✅ log4net.config found"
    } else {
        Write-DiagnosticLog -Level 'WARN' -Message "⚠️ log4net.config not found - may cause logging issues"
    }
    
    return $RVToolsPath
}

function Test-SystemResources {
    Write-DiagnosticLog -Level 'HEADER' -Message "System Resources Check"
    
    # Memory
    try {
        $memory = Get-WmiObject -Class Win32_ComputerSystem
        $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
        Write-DiagnosticLog -Level 'INFO' -Message "💾 Total Memory: ${totalMemoryGB}GB"
        
        if ($totalMemoryGB -lt 4) {
            Write-DiagnosticLog -Level 'WARN' -Message "⚠️ Low memory - RVTools may perform slowly"
        }
    } catch {
        Write-DiagnosticLog -Level 'WARN' -Message "⚠️ Could not check memory: $($_.Exception.Message)"
    }
    
    # Disk space
    try {
        $scriptDrive = Split-Path $PSScriptRoot -Qualifier
        $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$scriptDrive'"
        $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        Write-DiagnosticLog -Level 'INFO' -Message "💽 Free Disk Space ($scriptDrive): ${freeSpaceGB}GB"
        
        if ($freeSpaceGB -lt 2) {
            Write-DiagnosticLog -Level 'WARN' -Message "⚠️ Low disk space - exports may fail"
        }
    } catch {
        Write-DiagnosticLog -Level 'WARN' -Message "⚠️ Could not check disk space: $($_.Exception.Message)"
    }
    
    # PowerShell version
    Write-DiagnosticLog -Level 'INFO' -Message "🔧 PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-DiagnosticLog -Level 'INFO' -Message "🔧 .NET Version: $($PSVersionTable.CLRVersion)"
}

function Test-Credentials {
    param([string]$HostName, [PSCredential]$Credential)
    
    Write-DiagnosticLog -Level 'HEADER' -Message "Credential Testing"
    
    if (-not $Credential) {
        Write-DiagnosticLog -Level 'WARN' -Message "⚠️ No credentials provided - will prompt during RVTools execution"
        return
    }
    
    Write-DiagnosticLog -Level 'INFO' -Message "🔐 Username: $($Credential.UserName)"
    
    # Basic vCenter SDK test (if available)
    try {
        if (Get-Module VMware.VimAutomation.Core -ListAvailable) {
            Write-DiagnosticLog -Level 'INFO' -Message "🔌 Testing vCenter authentication with PowerCLI..."
            Import-Module VMware.VimAutomation.Core -ErrorAction Stop
            
            $connection = Connect-VIServer $HostName -Credential $Credential -ErrorAction Stop
            $vcInfo = Get-View ServiceInstance
            Write-DiagnosticLog -Level 'SUCCESS' -Message "✅ PowerCLI authentication successful"
            Write-DiagnosticLog -Level 'INFO' -Message "    vCenter Version: $($vcInfo.Content.About.Version)"
            Write-DiagnosticLog -Level 'INFO' -Message "    Build: $($vcInfo.Content.About.Build)"
            
            Disconnect-VIServer -Server $connection -Confirm:$false
        } else {
            Write-DiagnosticLog -Level 'INFO' -Message "ℹ️ PowerCLI not available - skipping credential validation"
        }
    } catch {
        Write-DiagnosticLog -Level 'ERROR' -Message "❌ vCenter authentication failed: $($_.Exception.Message)"
    }
}

function Test-RVToolsExport {
    param([string]$HostName, [PSCredential]$Credential, [string]$RVToolsPath)
    
    Write-DiagnosticLog -Level 'HEADER' -Message "RVTools Export Test"
    
    if (-not $Credential) {
        Write-DiagnosticLog -Level 'WARN' -Message "⚠️ Skipping export test - no credentials provided"
        return
    }
    
    $testDir = Join-Path $env:TEMP "RVToolsConnectivityTest"
    $testFile = "connectivity-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').xlsx"
    
    try {
        # Create test directory
        if (-not (Test-Path $testDir)) {
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
        }
        
        Write-DiagnosticLog -Level 'INFO' -Message "🧪 Attempting test export to: $testDir\$testFile"
        
        # Use the module function for the test
        $result = Invoke-RVToolsStandardExport `
            -HostName $HostName `
            -Credential $Credential `
            -RVToolsPath $RVToolsPath `
            -ExportDirectory $testDir `
            -ExportFileName $testFile `
            -LogFile $LogFile `
            -ConfigLogLevel 'INFO'
        
        if ($result.Success) {
            Write-DiagnosticLog -Level 'SUCCESS' -Message "✅ Test export successful!"
            
            $exportFile = Join-Path $testDir $testFile
            if (Test-Path $exportFile) {
                $fileInfo = Get-Item $exportFile
                Write-DiagnosticLog -Level 'INFO' -Message "    File size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB"
                Write-DiagnosticLog -Level 'INFO' -Message "    Created: $($fileInfo.CreationTime)"
            }
        } else {
            Write-DiagnosticLog -Level 'ERROR' -Message "❌ Test export failed: $($result.Message)"
        }
        
    } catch {
        Write-DiagnosticLog -Level 'ERROR' -Message "❌ Test export exception: $($_.Exception.Message)"
    } finally {
        # Clean up test files
        if (Test-Path $testDir) {
            try {
                Remove-Item $testDir -Recurse -Force
                Write-DiagnosticLog -Level 'INFO' -Message "🧹 Cleaned up test files"
            } catch {
                Write-DiagnosticLog -Level 'WARN' -Message "⚠️ Could not clean up test directory: $testDir"
            }
        }
    }
}

# Main diagnostic execution
Write-DiagnosticLog -Level 'HEADER' -Message "RVTools Connectivity Diagnostics"
Write-DiagnosticLog -Level 'INFO' -Message "Target: $HostName"
Write-DiagnosticLog -Level 'INFO' -Message "Started: $(Get-Date)"

# Run all diagnostic tests
$networkOk = Test-NetworkConnectivity -HostName $HostName
$detectedRVToolsPath = Test-RVToolsInstallation -RVToolsPath $RVToolsPath
Test-SystemResources

if ($Credential) {
    Test-Credentials -HostName $HostName -Credential $Credential
}

if ($TestExport -and $networkOk -and $detectedRVToolsPath) {
    Test-RVToolsExport -HostName $HostName -Credential $Credential -RVToolsPath $detectedRVToolsPath
}

Write-DiagnosticLog -Level 'HEADER' -Message "Diagnostics Complete"
Write-DiagnosticLog -Level 'INFO' -Message "Completed: $(Get-Date)"

if ($LogFile) {
    Write-DiagnosticLog -Level 'INFO' -Message "Full log saved to: $LogFile"
}
