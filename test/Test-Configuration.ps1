<#
.SYNOPSIS
    Test configuration file parsing and validation.

.DESCRIPTION
    This script tests the configuration file loading, template fallback,
    and configuration validation functionality of the RVTools toolkit.

.VERSION
    1.4.2

.PARAMETER ConfigPath
    Path to test a specific configuration file.

.PARAMETER TestTemplates
    Test template file loading.

.EXAMPLE
    .\Test-Configuration.ps1

.EXAMPLE
    .\Test-Configuration.ps1 -TestTemplates
#>

[CmdletBinding()]
param(
    [Parameter()] [string] $ConfigPath,
    [Parameter()] [switch] $TestTemplates
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

function Test-ConfigurationFile {
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [Parameter(Mandatory)] [string] $TestName
    )
    
    Write-Log -Level 'INFO' -Message "Testing: $TestName"
    
    try {
        if (-not (Test-Path $FilePath)) {
            Write-Log -Level 'FAIL' -Message "File not found: $FilePath"
            return $false
        }
        
        $config = Import-PowerShellDataFile -Path $FilePath
        Write-Log -Level 'SUCCESS' -Message "Successfully parsed: $FilePath"
        
        # Test required sections
        $requiredSections = @('RVToolsPath', 'Auth', 'Email')
        foreach ($section in $requiredSections) {
            if ($config.ContainsKey($section)) {
                Write-Log -Level 'SUCCESS' -Message "Required section found: $section"
            } else {
                Write-Log -Level 'FAIL' -Message "Missing required section: $section"
                return $false
            }
        }
        
        # Test Auth section structure
        if ($config.Auth) {
            $authKeys = @('Method', 'DefaultVault', 'SecretNamePattern')
            foreach ($key in $authKeys) {
                if ($config.Auth.ContainsKey($key)) {
                    Write-Log -Level 'SUCCESS' -Message "Auth.$key found: $($config.Auth[$key])"
                } else {
                    Write-Log -Level 'WARN' -Message "Optional Auth.$key not found"
                }
            }
        }
        
        # Test password encryption setting
        if ($config.Auth.ContainsKey('UsePasswordEncryption')) {
            Write-Log -Level 'SUCCESS' -Message "UsePasswordEncryption: $($config.Auth.UsePasswordEncryption)"
        } else {
            Write-Log -Level 'WARN' -Message "UsePasswordEncryption not specified (will default to true)"
        }
        
        return $true
    } catch {
        Write-Log -Level 'ERROR' -Message "Failed to parse $FilePath : $($_.Exception.Message)"
        return $false
    }
}

function Test-HostListFile {
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [Parameter(Mandatory)] [string] $TestName
    )
    
    Write-Log -Level 'INFO' -Message "Testing: $TestName"
    
    try {
        if (-not (Test-Path $FilePath)) {
            Write-Log -Level 'FAIL' -Message "File not found: $FilePath"
            return $false
        }
        
        $hostData = Import-PowerShellDataFile -Path $FilePath
        Write-Log -Level 'SUCCESS' -Message "Successfully parsed: $FilePath"
        
        if ($hostData -and $hostData.ContainsKey('Hosts') -and $hostData.Hosts -and $hostData.Hosts.Count -gt 0) {
            $hostList = $hostData.Hosts
            Write-Log -Level 'SUCCESS' -Message "Host list contains $($hostList.Count) entries"
            
            foreach ($i in 0..([Math]::Min($hostList.Count - 1, 2))) {
                $hostEntry = $hostList[$i]
                $hostType = $hostEntry.GetType().Name
                Write-Log -Level 'INFO' -Message "Entry $($i + 1): Type=$hostType"
                
                switch ($hostType) {
                    'String' {
                        Write-Log -Level 'SUCCESS' -Message "  Host: $hostEntry"
                    }
                    'Hashtable' {
                        if ($hostEntry.ContainsKey('Name')) {
                            Write-Log -Level 'SUCCESS' -Message "  Host: $($hostEntry.Name)"
                            if ($hostEntry.ContainsKey('Username')) {
                                Write-Log -Level 'SUCCESS' -Message "  Username: $($hostEntry.Username)"
                            }
                        } else {
                            Write-Log -Level 'FAIL' -Message "  Hashtable missing 'Name' key"
                            return $false
                        }
                    }
                    default {
                        Write-Log -Level 'WARN' -Message "  Unexpected hostEntry entry type: $hostType"
                    }
                }
            }
        } else {
            Write-Log -Level 'FAIL' -Message "Host list is empty, null, or missing 'Hosts' property"
            return $false
        }
        
        return $true
    } catch {
        Write-Log -Level 'ERROR' -Message "Failed to parse $FilePath : $($_.Exception.Message)"
        return $false
    }
}

# Main test execution
Write-Log -Level 'INFO' -Message "RVTools Configuration Tests"
Write-Log -Level 'INFO' -Message "============================"

$scriptRoot = Split-Path -Parent $PSScriptRoot
$testResults = @()

# Test configuration files
if ($ConfigPath) {
    $testResults += Test-ConfigurationFile -FilePath $ConfigPath -TestName "Custom Configuration"
} else {
    # Test template configuration
    $configTemplate = Join-Path $scriptRoot "shared\Configuration-Template.psd1"
    $testResults += Test-ConfigurationFile -FilePath $configTemplate -TestName "Configuration Template"
    
    # Test live configuration if it exists
    $liveConfig = Join-Path $scriptRoot "shared\Configuration.psd1"
    if (Test-Path $liveConfig) {
        $testResults += Test-ConfigurationFile -FilePath $liveConfig -TestName "Live Configuration"
    } else {
        Write-Log -Level 'INFO' -Message "Live configuration not found (expected for clean repo)"
    }
}

# Test host list files
$hostTemplate = Join-Path $scriptRoot "shared\HostList-Template.psd1"
$testResults += Test-HostListFile -FilePath $hostTemplate -TestName "Host List Template"

$liveHostList = Join-Path $scriptRoot "shared\HostList.psd1"
if (Test-Path $liveHostList) {
    $testResults += Test-HostListFile -FilePath $liveHostList -TestName "Live Host List"
} else {
    Write-Log -Level 'INFO' -Message "Live host list not found (expected for clean repo)"
}

# Test summary
Write-Log -Level 'INFO' -Message " "
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
