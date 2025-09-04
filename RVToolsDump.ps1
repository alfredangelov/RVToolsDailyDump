<#
.SYNOPSIS
    Run RVTools exports for a list of vCenter servers with config-driven settings.

.DESCRIPTION
    This script reads configuration from `shared/Configuration.psd1` and a host list from
    `shared/HostList.psd1` (ignored by Git). It writes logs to `logs/` and exports to the
    configured folder. Use the `*-Template.psd1` files as examples to create your local
    `Configuration.psd1` and `HostList.psd1`.

    This is a completely refactored version that leverages the RVToolsModule public functions,
    reducing code duplication and improving maintainability.

.PARAMETER ConfigPath
    Path to a PSD1 configuration file. Defaults to `shared/Configuration.psd1`.

.PARAMETER HostListPath
    Path to a PSD1 host list file. Defaults to `shared/HostList.psd1`.

.PARAMETER NoEmail
    Skip sending email even if enabled in configuration.

.PARAMETER ChunkedExport
    Force chunked export mode for all hosts. Individual hosts can also specify
    ExportMode = 'Chunked' in the host list configuration. Use this mode when 
    large vCenter environments cause RVTools to crash during full export. 
    Each tab is exported individually, reducing memory usage.

.NOTES
    Version: 3.2.0
    - Completely refactored to use RVToolsModule public functions
    - Removed ~200+ lines of duplicated code
    - Improved maintainability and error handling
    - Better separation of concerns
    - Keep live config files out of source control. Templates are provided under `shared/`.
    - Credentials are requested securely at runtime. Password is passed to RVTools as plain text
      command-line argument (required by RVTools). Use a low-privilege service account.
    - PowerShell 7+ compatible.
    - ImportExcel module integration - no Microsoft Excel installation required.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()] [string] $ConfigPath = (Join-Path $PSScriptRoot 'shared/Configuration.psd1'),
    [Parameter()] [string] $HostListPath = (Join-Path $PSScriptRoot 'shared/HostList.psd1'),
    [Parameter()] [switch] $NoEmail,
    [Parameter()] [switch] $DryRun,
    [Parameter()] [switch] $ChunkedExport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import RVTools module for common functions
try {
    Import-Module (Join-Path $PSScriptRoot 'RVToolsModule') -Force -ErrorAction Stop
    Write-Verbose "RVToolsModule loaded successfully"
} catch {
    Write-Error "Failed to load RVToolsModule: $($_.Exception.Message)"
    exit 1
}

# Use the module's main export function with parameter mapping
$moduleParams = @{
    ConfigPath = $ConfigPath
    HostListPath = $HostListPath
    DryRun = $DryRun
}

# Add optional parameters if they were specified
if ($ChunkedExport) { $moduleParams.ChunkedExport = $true }
if ($NoEmail) { $moduleParams.NoEmail = $true }

# Execute the main export function
try {
    $results = Invoke-RVToolsExport @moduleParams
    
    # Convert results to legacy status format for backward compatibility
    $overallStatus = $results | ForEach-Object { 
        if ($_.Success) {
            if ($_.PSObject.Properties['SuccessfulTabs']) {
                # Chunked export result
                if ($_.FailedTabs -eq 0) {
                    "SUCCESS (CHUNKED) - $($_.HostName)"
                } else {
                    "PARTIAL SUCCESS (CHUNKED $($_.SuccessfulTabs)/$($_.SuccessfulTabs + $_.FailedTabs)) - $($_.HostName)"
                }
            } else {
                # Standard export result
                "$($_.Message) - $($_.HostName)"
            }
        } else {
            "$($_.Message) - $($_.HostName)"
        }
    }
    
    Write-Host ("Run complete. Summary: {0}" -f ($overallStatus -join '; '))
    
} catch {
    Write-Error "Export failed: $($_.Exception.Message)"
    exit 1
}
