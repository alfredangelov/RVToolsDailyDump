<#
.SYNOPSIS
    Upload RVTools exports to SharePoint using PnP PowerShell.

.DESCRIPTION
    This script uploads Excel files from the exports folder to a SharePoint
    document library for easy access via Teams and web interface.

.VERSION
    1.4.2

.PARAMETER ConfigPath
    Path to the configuration file. Defaults to shared/Configuration.psd1.

.PARAMETER ExportFile
    Specific export file to upload. If not specified, uploads all files from today.

.PARAMETER UploadAll
    Upload all export files in the exports folder.

.EXAMPLE
    .\Upload-ToSharePoint.ps1

.EXAMPLE
    .\Upload-ToSharePoint.ps1 -ExportFile "vcenter01-20250815_143022.xlsx"
#>

[CmdletBinding()]
param(
    [Parameter()] [string] $ConfigPath = (Join-Path $PSScriptRoot 'shared/Configuration.psd1'),
    [Parameter()] [string] $ExportFile,
    [Parameter()] [switch] $UploadAll
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')] [string] $Level = 'INFO'
    )
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
}

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    Write-Log -Level 'ERROR' -Message "Configuration file not found: $ConfigPath"
    exit 1
}

$cfg = Import-PowerShellDataFile -Path $ConfigPath

# Check SharePoint configuration
if (-not $cfg.SharePoint?.Enabled) {
    Write-Log -Level 'ERROR' -Message "SharePoint integration not enabled in configuration"
    exit 1
}

$siteUrl = $cfg.SharePoint.SiteUrl
$docLibrary = $cfg.SharePoint.DocumentLibrary
$credentialSecret = $cfg.SharePoint.CredentialSecret

# Check PnP PowerShell module
try {
    Import-Module PnP.PowerShell -ErrorAction Stop
    Write-Log -Level 'INFO' -Message "PnP PowerShell module loaded successfully"
} catch {
    Write-Log -Level 'ERROR' -Message "PnP PowerShell module not available. Please install with: Install-Module PnP.PowerShell"
    exit 1
}

# Get SharePoint credentials
try {
    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
    $vaultName = $cfg.Auth?.DefaultVault ?? 'RVToolsVault'
    $spCredential = Get-Secret -Name $credentialSecret -Vault $vaultName
    Write-Log -Level 'INFO' -Message "Retrieved SharePoint credentials from SecretManagement"
} catch {
    Write-Log -Level 'ERROR' -Message "Failed to retrieve SharePoint credentials: $($_.Exception.Message)"
    Write-Log -Level 'INFO' -Message "Please store SharePoint credentials using: Set-RVToolsCredentials.ps1"
    exit 1
}

# Connect to SharePoint
try {
    Write-Log -Level 'INFO' -Message "Connecting to SharePoint: $siteUrl"
    Connect-PnPOnline -Url $siteUrl -Credential $spCredential
    Write-Log -Level 'SUCCESS' -Message "Connected to SharePoint successfully"
} catch {
    Write-Log -Level 'ERROR' -Message "Failed to connect to SharePoint: $($_.Exception.Message)"
    exit 1
}

# Determine files to upload
$exportsRoot = Join-Path $PSScriptRoot ($cfg.ExportFolder ?? 'exports')
$filesToUpload = @()

if ($ExportFile) {
    $fullPath = Join-Path $exportsRoot $ExportFile
    if (Test-Path $fullPath) {
        $filesToUpload += Get-Item $fullPath
    } else {
        Write-Log -Level 'ERROR' -Message "Export file not found: $fullPath"
        exit 1
    }
} elseif ($UploadAll) {
    $filesToUpload = Get-ChildItem -Path $exportsRoot -Filter "*.xlsx"
} else {
    # Upload files from today
    $today = Get-Date -Format 'yyyyMMdd'
    $filesToUpload = Get-ChildItem -Path $exportsRoot -Filter "*$today*.xlsx"
}

if (-not $filesToUpload) {
    Write-Log -Level 'WARN' -Message "No files found to upload"
    exit 0
}

Write-Log -Level 'INFO' -Message "Found $($filesToUpload.Count) file(s) to upload"

# Upload files
$uploadedCount = 0
foreach ($file in $filesToUpload) {
    try {
        Write-Log -Level 'INFO' -Message "Uploading: $($file.Name)"
        
        # Create folder structure by date if needed
        $fileDate = [regex]::Match($file.Name, '\d{8}').Value
        if ($fileDate) {
            $folderName = "{0}-{1}-{2}" -f $fileDate.Substring(0,4), $fileDate.Substring(4,2), $fileDate.Substring(6,2)
            $targetFolder = "$docLibrary/$folderName"
            
            # Ensure folder exists
            try {
                Get-PnPFolder -Url $targetFolder -ErrorAction Stop | Out-Null
            } catch {
                Write-Log -Level 'INFO' -Message "Creating folder: $folderName"
                New-PnPFolder -Name $folderName -Folder $docLibrary | Out-Null
            }
            
            # Upload to date folder
            Add-PnPFile -Path $file.FullName -Folder $targetFolder | Out-Null
        } else {
            # Upload to root of document library
            Add-PnPFile -Path $file.FullName -Folder $docLibrary | Out-Null
        }
        
        Write-Log -Level 'SUCCESS' -Message "Uploaded: $($file.Name)"
        $uploadedCount++
    } catch {
        Write-Log -Level 'ERROR' -Message "Failed to upload $($file.Name): $($_.Exception.Message)"
    }
}

# Disconnect
Disconnect-PnPOnline

Write-Log -Level 'SUCCESS' -Message "Upload complete. $uploadedCount of $($filesToUpload.Count) files uploaded successfully."
