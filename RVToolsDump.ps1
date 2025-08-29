<#
.SYNOPSIS
    Run RVTools exports for a list of vCenter servers with config-driven settings.

.DESCRIPTION
    This script reads configuration from `shared/Configuration.psd1` and a host list from
    `shared/HostList.psd1` (ignored by Git). It writes logs to `logs/` and exports to the
    configured folder. Use the `*-Template.psd1` files as examples to create your local
    `Configuration.psd1` and `HostList.psd1`.

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
    Version: 1.3.0
    - Keep live config files out of source control. Templates are provided under `shared/`.
    - Credentials are requested securely at runtime. Password is passed to RVTools as plain text
      command-line argument (required by RVTools). Use a low-privilege service account.
    - PowerShell 7+ compatible.
    - New in v1.3.0: Chunked export mode for large environments with memory issues.
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

# Import SecretManagement module if available and using SecretManagement auth
try {
    if (-not $DryRun) {
        Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
        Write-Verbose "SecretManagement module loaded successfully"
    }
} catch {
    Write-Warning "SecretManagement module not available. Falling back to prompt authentication."
}

function Resolve-PathOrCombine {
    param(
        [Parameter(Mandatory)] [string] $Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    try { return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path } catch { return (Join-Path $PSScriptRoot $Path) }
}

function Ensure-Directory {
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        $null = New-Item -ItemType Directory -Force -Path $Path
    }
}

function Import-DataFileOrTemplate {
    param(
        [Parameter(Mandatory)] [string] $LivePath,
        [Parameter(Mandatory)] [string] $TemplateName,
        [Parameter(Mandatory)] [string] $Purpose,
        [switch] $PreferTemplate
    )
    $templatePath = Join-Path $PSScriptRoot ("shared/{0}" -f $TemplateName)
    if ($PreferTemplate -and (Test-Path -LiteralPath $templatePath)) {
        Write-Warning "Using template $TemplateName for $Purpose (dry-run or preference)."
        return [pscustomobject]@{ Data = (Import-PowerShellDataFile -Path $templatePath); UsingTemplate = $true; Path = $templatePath }
    }
    if (Test-Path -LiteralPath $LivePath) {
        try {
            $data = Import-PowerShellDataFile -Path $LivePath
            return [pscustomobject]@{ Data = $data; UsingTemplate = $false; Path = $LivePath }
        } catch {
            Write-Warning "Failed to parse $Purpose at '$LivePath': $($_.Exception.Message)"
            if (Test-Path -LiteralPath $templatePath) {
                Write-Warning "Falling back to template $TemplateName for $Purpose."
                return [pscustomobject]@{ Data = (Import-PowerShellDataFile -Path $templatePath); UsingTemplate = $true; Path = $templatePath }
            }
            throw
        }
    } elseif (Test-Path -LiteralPath $templatePath) {
        Write-Warning "Live $Purpose not found. Using template $TemplateName."
        return [pscustomobject]@{ Data = (Import-PowerShellDataFile -Path $templatePath); UsingTemplate = $true; Path = $templatePath }
    } else {
        throw "Neither live $Purpose ('$LivePath') nor template ('$templatePath') found."
    }
}

# Load configuration (prefer live file; fall back to template for discovery)
$cfgResult = Import-DataFileOrTemplate -LivePath $ConfigPath -TemplateName 'Configuration-Template.psd1' -Purpose 'configuration' -PreferTemplate:$DryRun
$cfg = $cfgResult.Data
$usingTemplateCfg = $cfgResult.UsingTemplate
$DryRun = $DryRun -or $usingTemplateCfg

# Set up logging configuration
$script:ConfigLogLevel = $cfg.Logging?.LogLevel ?? 'INFO'

# Resolve paths
$rvtoolsPath  = Resolve-PathOrCombine -Path ($cfg.RVToolsPath)
$exportsRoot  = Resolve-PathOrCombine -Path (($cfg.ExportFolder) ?? 'exports')
$logsRoot     = Resolve-PathOrCombine -Path (($cfg.LogsFolder) ?? 'logs')

Ensure-Directory -Path $exportsRoot
Ensure-Directory -Path $logsRoot

$script:LogFile = Join-Path $logsRoot ("RVTools_RunLog_{0}.txt" -f (Get-Date -Format 'yyyyMMdd'))

function Write-Log {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','DEBUG')] [string] $Level = 'INFO'
    )
    
    # Check if we should log this level
    $configLogLevel = $script:ConfigLogLevel ?? 'INFO'
    $logLevels = @('DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS')
    $currentIndex = $logLevels.IndexOf($configLogLevel)
    $messageIndex = $logLevels.IndexOf($Level)
    
    if ($messageIndex -ge $currentIndex -or $Level -eq 'SUCCESS') {
        $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        
        if ($script:LogFile) {
            $line | Tee-Object -FilePath $script:LogFile -Append | Out-Host
        } else {
            Write-Host $line
        }
    }
}

if (-not $DryRun) {
    if (-not (Test-Path -LiteralPath $rvtoolsPath)) {
        throw "RVTools executable not found at '$rvtoolsPath'. Update RVToolsPath in the configuration."
    }
} else {
    Write-Log -Level 'WARN' -Message "Dry-run mode: RVTools path check skipped."
}

# Load host list
$hostsResult = Import-DataFileOrTemplate -LivePath $HostListPath -TemplateName 'HostList-Template.psd1' -Purpose 'host list' -PreferTemplate:$DryRun
$hostItems = $hostsResult.Data.Hosts

if (-not $hostItems) { throw "Host list is empty in '$($hostsResult.Path)'" }

# Normalize host entries into [pscustomobject] with Name + optional Username + optional ExportMode
$servers = @(
    foreach ($item in $hostItems) {
    switch ($item.GetType().Name) {
        'String'      { [pscustomobject]@{ Name = $item; Username = $null; ExportMode = 'Normal' } }
        'Hashtable'   { [pscustomobject]@{ Name = $item.Name; Username = $item.Username; ExportMode = if ($item.ContainsKey('ExportMode')) { $item.ExportMode } else { 'Normal' } } }
        'PSCustomObject' { [pscustomobject]@{ Name = $item.Name; Username = $item.Username; ExportMode = if ($item.PSObject.Properties['ExportMode']) { $item.ExportMode } else { 'Normal' } } }
        default       { Write-Warning "Unsupported host list entry type: $($item.GetType().FullName)"; continue }
    }
    }
) | Where-Object { $_.Name }

if (-not $servers) { throw "No valid servers found in host list." }

# Auth settings
$authMethod = ($cfg.Auth?.Method ?? 'Prompt')
$defaultUsername = $cfg.Auth?.Username
$vaultName = $cfg.Auth?.DefaultVault ?? 'RVToolsVault'
$secretPattern = $cfg.Auth?.SecretNamePattern ?? '{HostName}-{Username}'
$usePasswordEncryption = $cfg.Auth?.UsePasswordEncryption ?? $true

function Get-RVToolsEncryptedPassword {
    param(
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential] $Credential
    )
    
    # Convert password to secure string and then to encrypted string using DPAPI
    $securePassword = $Credential.Password
    $encryptedPassword = $securePassword | ConvertFrom-SecureString
    
    # Add RVTools prefix so it knows this is an encrypted password
    return '_RVToolsV3PWD' + $encryptedPassword
}

function Get-SecretName {
    param(
        [Parameter(Mandatory)] [string] $HostName,
        [Parameter(Mandatory)] [string] $Username,
        [Parameter(Mandatory)] [string] $Pattern
    )
    return $Pattern -replace '\{HostName\}', $HostName -replace '\{Username\}', $Username
}

# Cache credentials by username
$credCache = @{}
function Get-CredForUser {
    param(
        [Parameter(Mandatory)] [string] $Username,
        [Parameter(Mandatory)] [string] $HostName
    )
    
    $cacheKey = "$HostName-$Username"
    if ($credCache.ContainsKey($cacheKey)) { 
        Write-Log -Level 'DEBUG' -Message "Using cached credential for $Username on $HostName"
        return $credCache[$cacheKey] 
    }
    
    $cred = $null
    
    # Try SecretManagement first if configured
    if ($authMethod -eq 'SecretManagement' -and -not $DryRun) {
        try {
            $secretName = Get-SecretName -HostName $HostName -Username $Username -Pattern $secretPattern
            Write-Log -Level 'DEBUG' -Message "Looking for secret: $secretName in vault: $vaultName"
            $cred = Get-Secret -Name $secretName -Vault $vaultName -ErrorAction Stop
            Write-Log -Level 'DEBUG' -Message "Retrieved credential for $Username on $HostName from SecretManagement"
        } catch {
            Write-Log -Level 'WARN' -Message "Failed to retrieve credential for $Username on $HostName from SecretManagement: $($_.Exception.Message)"
            Write-Log -Level 'INFO' -Message "Falling back to prompt authentication"
        }
    }
    
    # Fall back to prompt if SecretManagement failed or not configured
    if (-not $cred) {
        $cred = Get-Credential -UserName $Username -Message "Enter password for $Username on $HostName"
    }
    
    $credCache[$cacheKey] = $cred
    return $cred
}

$extraArgs = @()
if ($cfg.RVToolsArgs) { $extraArgs += [string[]]$cfg.RVToolsArgs }

# Define RVTools tabs for chunked export
$rvToolsTabs = @(
    @{ Command = 'ExportvInfo2xlsx'; FileName = 'vInfo' },
    @{ Command = 'ExportvCPU2xlsx'; FileName = 'vCPU' },
    @{ Command = 'ExportvMemory2xlsx'; FileName = 'vMemory' },
    @{ Command = 'ExportvDisk2xlsx'; FileName = 'vDisk' },
    @{ Command = 'ExportvPartition2xlsx'; FileName = 'vPartition' },
    @{ Command = 'ExportvNetwork2xlsx'; FileName = 'vNetwork' },
    @{ Command = 'ExportvUSB2xlsx'; FileName = 'vUSB' },
    @{ Command = 'ExportvCD2xlsx'; FileName = 'vCD' },
    @{ Command = 'ExportvSnapshot2xlsx'; FileName = 'vSnapshot' },
    @{ Command = 'ExportvTools2xlsx'; FileName = 'vTools' },
    @{ Command = 'ExportvSource2xlsx'; FileName = 'vSource' },
    @{ Command = 'ExportvRP2xlsx'; FileName = 'vRP' },
    @{ Command = 'ExportvCluster2xlsx'; FileName = 'vCluster' },
    @{ Command = 'ExportvHost2xlsx'; FileName = 'vHost' },
    @{ Command = 'ExportvHBA2xlsx'; FileName = 'vHBA' },
    @{ Command = 'ExportvNIC2xlsx'; FileName = 'vNIC' },
    @{ Command = 'ExportvSwitch2xlsx'; FileName = 'vSwitch' },
    @{ Command = 'ExportvPort2xlsx'; FileName = 'vPort' },
    @{ Command = 'ExportdvSwitch2xlsx'; FileName = 'dvSwitch' },
    @{ Command = 'ExportdvPort2xlsx'; FileName = 'dvPort' },
    @{ Command = 'ExportvSC+VMK2xlsx'; FileName = 'vSC_VMK' },
    @{ Command = 'ExportvDatastore2xlsx'; FileName = 'vDatastore' },
    @{ Command = 'ExportvMultiPath2xlsx'; FileName = 'vMultiPath' },
    @{ Command = 'ExportvLicense2xlsx'; FileName = 'vLicense' },
    @{ Command = 'ExportvFileInfo2xlsx'; FileName = 'vFileInfo' },
    @{ Command = 'ExportvHealth2xlsx'; FileName = 'vHealth' }
)

function Merge-ExcelFiles {
    param(
        [Parameter(Mandatory)] [string[]] $SourceFiles,
        [Parameter(Mandatory)] [string] $DestinationFile
    )
    
    # Filter to only existing files
    $existingFiles = $SourceFiles | Where-Object { Test-Path $_ }
    
    if ($existingFiles.Count -eq 0) {
        Write-Log -Level 'ERROR' -Message "No source files exist to merge"
        return $false
    }
    
    Write-Log -Message "Merging $($existingFiles.Count) Excel files into $DestinationFile"
    
    try {
        # Load the Excel COM object
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        
        # Open the first file as the destination workbook
        $destinationWorkbook = $excel.Workbooks.Open($existingFiles[0])
        Write-Log -Level 'DEBUG' -Message "Opened first file as base: $($existingFiles[0])"
        
        # Process remaining files (if any)
        for ($i = 1; $i -lt $existingFiles.Count; $i++) {
            $sourceFile = $existingFiles[$i]
            Write-Log -Level 'DEBUG' -Message "Processing $sourceFile"
            $sourceWorkbook = $excel.Workbooks.Open($sourceFile)
            
            # Copy worksheets from source to destination, but skip vMetaData tabs from subsequent files
            foreach ($worksheet in $sourceWorkbook.Worksheets) {
                # Skip vMetaData tabs from files after the first one (they should be identical)
                if ($worksheet.Name -eq 'vMetaData') {
                    Write-Log -Level 'DEBUG' -Message "Skipping duplicate vMetaData tab from $sourceFile"
                    continue
                }
                $worksheet.Copy([System.Reflection.Missing]::Value, $destinationWorkbook.Worksheets.Item($destinationWorkbook.Worksheets.Count))
            }
            
            $sourceWorkbook.Close($false)
            Write-Log -Level 'DEBUG' -Message "Merged worksheets from $sourceFile (excluding duplicate vMetaData)"
        }
        
        # Save the merged workbook with new name
        $destinationWorkbook.SaveAs($DestinationFile)
        $destinationWorkbook.Close($false)
        $excel.Quit()
        
        # Clean up COM objects
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($destinationWorkbook) | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        [System.GC]::Collect()
        
        Write-Log -Level 'SUCCESS' -Message "Successfully merged $($existingFiles.Count) Excel files into $DestinationFile"
        return $true
    } catch {
        Write-Log -Level 'ERROR' -Message "Failed to merge Excel files: $($_.Exception.Message)"
        
        # Cleanup on error
        try {
            if ($destinationWorkbook) { $destinationWorkbook.Close($false) }
            if ($excel) { $excel.Quit() }
        } catch { }
        
        return $false
    }
}

$overallStatus = @()

foreach ($server in $servers) {
    $name = $server.Name
    $user = if ($server.Username) { $server.Username } elseif ($defaultUsername) { $defaultUsername } else { '' }
    $serverExportMode = if ($server.ExportMode) { $server.ExportMode } else { 'Normal' }  # Default to Normal if not specified
    
    # Determine if this server should use chunked export
    $useChunkedExport = $ChunkedExport -or ($serverExportMode -eq 'Chunked')
    
    Write-Log -Message "Processing $name with export mode: $serverExportMode"

    if (-not $DryRun) {
        if ([string]::IsNullOrWhiteSpace($user) -and $authMethod -eq 'Prompt') {
            # Ask for username interactively once per server
            $user = Read-Host -Prompt "Enter username for $name"
        }
    }

    if ([string]::IsNullOrWhiteSpace($user)) {
        Write-Log -Level 'WARN' -Message "Skipping $name because no username provided."
        continue
    }

    $cred = $null
    $passwordArg = $null
    if (-not $DryRun) {
        $cred = Get-CredForUser -Username $user -HostName $name
        if ($usePasswordEncryption) {
            $passwordArg = Get-RVToolsEncryptedPassword -Credential $cred
            Write-Log -Level 'DEBUG' -Message "Using encrypted password for $user on $name"
        } else {
            $passwordArg = $cred.GetNetworkCredential().Password
            Write-Log -Level 'DEBUG' -Message "Using plaintext password for $user on $name"
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $exportFileName = "{0}-{1}.xlsx" -f $name, $timestamp
    $exportFile = Join-Path $exportsRoot $exportFileName

    if ($useChunkedExport) {
        # Chunked export mode - export each tab separately then merge
        Write-Log -Message "Starting chunked export for $name (mode: $serverExportMode)"
        $tempFiles = @()
        $allTabsSucceeded = $true
        $successfulTabs = @()
        $failedTabs = @()
        
        foreach ($tab in $rvToolsTabs) {
            $tabFileName = "{0}-{1}-{2}.xlsx" -f $name, $timestamp, $tab.FileName
            $tabFile = Join-Path $exportsRoot $tabFileName
            
            $args = if (-not $DryRun) {
                @('-c', $tab.Command, '-s', $name, '-u', $cred.UserName, '-p', $passwordArg, '-d', "`"$exportsRoot`"", '-f', $tabFileName) + $extraArgs
            } else {
                $simUser = if ($user) { $user } else { '<username>' }
                $pwdDisplay = if ($usePasswordEncryption) { '<encrypted>' } else { '<redacted>' }
                @('-c', $tab.Command, '-s', $name, '-u', $simUser, '-p', $pwdDisplay, '-d', "`"$exportsRoot`"", '-f', $tabFileName) + $extraArgs
            }
            
            try {
                if ($PSCmdlet.ShouldProcess($name, "Export $($tab.FileName) tab")) {
                    if (-not $DryRun) {
                        Write-Log -Level 'DEBUG' -Message "Exporting $($tab.FileName) tab for $name"
                        
                        # Change to RVTools directory
                        $originalLocation = Get-Location
                        Set-Location (Split-Path $rvtoolsPath -Parent)
                        
                        try {
                            $process = Start-Process -FilePath $rvtoolsPath -ArgumentList $args -NoNewWindow -Wait -PassThru
                            $code = $process.ExitCode
                            
                            if ($code -eq 0) {
                                Write-Log -Level 'DEBUG' -Message "Successfully exported $($tab.FileName) tab for $name"
                                if (Test-Path $tabFile) {
                                    $tempFiles += $tabFile
                                    $successfulTabs += $tab.FileName
                                }
                            } elseif ($code -eq -1) {
                                Write-Log -Level 'WARN' -Message "Failed to export $($tab.FileName) tab for $name (connection failed)"
                                $allTabsSucceeded = $false
                                $failedTabs += "$($tab.FileName) (connection failed)"
                            } elseif ($code -eq -1073741819) {
                                Write-Log -Level 'WARN' -Message "Failed to export $($tab.FileName) tab for $name (crash/memory issue)"
                                $allTabsSucceeded = $false
                                $failedTabs += "$($tab.FileName) (crash)"
                            } else {
                                Write-Log -Level 'WARN' -Message "Failed to export $($tab.FileName) tab for $name (exit code $code)"
                                $allTabsSucceeded = $false
                                $failedTabs += "$($tab.FileName) (exit $code)"
                            }
                        } finally {
                            Set-Location $originalLocation
                        }
                    } else {
                        Write-Log -Message "[Dry-Run] Would export $($tab.FileName): $rvtoolsPath $($args -join ' ')"
                        $tempFiles += $tabFile  # Simulate file creation for dry run
                        $successfulTabs += $tab.FileName
                    }
                }
            } catch {
                Write-Log -Level 'ERROR' -Message "Exception while exporting $($tab.FileName) tab for ${name}: $($_.Exception.Message)"
                $allTabsSucceeded = $false
                $failedTabs += "$($tab.FileName) (exception)"
            }
        }
        
        Write-Log -Message "Tab export summary for $name - Successful: $($successfulTabs.Count), Failed: $($failedTabs.Count)"
        if ($failedTabs.Count -gt 0) {
            Write-Log -Level 'WARN' -Message "Failed tabs: $($failedTabs -join ', ')"
        }
        
        # Merge all tab files into final export file
        if ($tempFiles.Count -gt 0) {
            if (-not $DryRun) {
                # Filter to only files that actually exist
                $existingTempFiles = $tempFiles | Where-Object { Test-Path $_ }
                
                if ($existingTempFiles.Count -gt 0) {
                    Write-Log -Message "Found $($existingTempFiles.Count) successful tab exports out of $($tempFiles.Count) attempted"
                    $mergeSucceeded = Merge-ExcelFiles -SourceFiles $existingTempFiles -DestinationFile $exportFile
                    
                    if ($mergeSucceeded) {
                        # Clean up ALL tab files for this timestamp, including failed/stub files
                        $allTabPattern = "{0}-{1}-*.xlsx" -f $name, $timestamp
                        $allTabFiles = Get-ChildItem -Path $exportsRoot -Filter $allTabPattern
                        foreach ($tabFile in $allTabFiles) {
                            try {
                                Remove-Item $tabFile.FullName -Force
                                Write-Log -Level 'DEBUG' -Message "Cleaned up tab file: $($tabFile.Name)"
                            } catch {
                                Write-Log -Level 'WARN' -Message "Failed to remove tab file $($tabFile.Name): $($_.Exception.Message)"
                            }
                        }
                        
                        if ($allTabsSucceeded) {
                            Write-Log -Level 'SUCCESS' -Message "Completed chunked export for $name"
                            $overallStatus += "SUCCESS (CHUNKED) - $name"
                        } else {
                            Write-Log -Level 'SUCCESS' -Message "Completed partial chunked export for $name ($($existingTempFiles.Count)/$($tempFiles.Count) tabs)"
                            $overallStatus += "PARTIAL SUCCESS (CHUNKED $($existingTempFiles.Count)/$($tempFiles.Count)) - $name"
                        }
                    } else {
                        Write-Log -Level 'ERROR' -Message "Failed to merge tab files for $name"
                        $overallStatus += "MERGE FAILED (CHUNKED) - $name"
                    }
                } else {
                    Write-Log -Level 'ERROR' -Message "No successful tab exports found for $name"
                    $overallStatus += "NO TABS EXPORTED (CHUNKED) - $name"
                }
            } else {
                Write-Log -Message "[Dry-Run] Would merge $($tempFiles.Count) tab files into $exportFile"
                $overallStatus += "DRYRUN (CHUNKED) - $name"
            }
        } else {
            Write-Log -Level 'ERROR' -Message "No tab files were created for $name"
            $overallStatus += "FAILURE (CHUNKED) - $name"
        }
    } else {
        # Standard export mode - export all tabs at once
        $args = if (-not $DryRun) {
            @('-c', 'ExportAll2xlsx', '-s', $name, '-u', $cred.UserName, '-p', $passwordArg, '-d', "`"$exportsRoot`"", '-f', $exportFileName) + $extraArgs
        } else {
            $simUser = if ($user) { $user } else { '<username>' }
            $pwdDisplay = if ($usePasswordEncryption) { '<encrypted>' } else { '<redacted>' }
            @('-c', 'ExportAll2xlsx', '-s', $name, '-u', $simUser, '-p', $pwdDisplay, '-d', "`"$exportsRoot`"", '-f', $exportFileName) + $extraArgs
        }

        try {
            if ($PSCmdlet.ShouldProcess($name, 'Run RVTools export')) {
                if (-not $DryRun) {
                    Write-Log -Message "Starting RVTools export for $name to $exportFile"
                    
                    # Change to RVTools directory (as recommended by Dell)
                    $originalLocation = Get-Location
                    Set-Location (Split-Path $rvtoolsPath -Parent)
                    
                    try {
                        # Use Start-Process as recommended by Dell's official script
                        $process = Start-Process -FilePath $rvtoolsPath -ArgumentList $args -NoNewWindow -Wait -PassThru
                        $code = $process.ExitCode
                        
                        if ($code -eq 0) {
                            Write-Log -Level 'SUCCESS' -Message "Completed export for $name"
                            $overallStatus += "SUCCESS - $name"
                        } elseif ($code -eq -1) {
                            Write-Log -Level 'ERROR' -Message "RVTools connection failed for $name (exit code -1)"
                            $overallStatus += "CONNECTION FAILED - $name"
                        } else {
                            Write-Log -Level 'ERROR' -Message "RVTools exit code $code for $name"
                            $overallStatus += "FAILURE ($code) - $name"
                        }
                    } finally {
                        # Restore original location
                        Set-Location $originalLocation
                    }
                } else {
                    Write-Log -Message "[Dry-Run] Would run: $rvtoolsPath $($args -join ' ')"
                    $overallStatus += "DRYRUN - $name"
                }
            }
        } catch {
            $err = $_
            Write-Log -Level 'ERROR' -Message "Exception while exporting ${name}: $($err.Exception.Message)"
            $overallStatus += "ERROR - ${name} - $($err.Exception.Message)"
        }
    }
}

# Email summary
$emailCfg = $cfg.Email
if ($emailCfg.Enabled -and -not $NoEmail -and -not $DryRun) {
    $canEmail = $null -ne (Get-Command -Name Send-MailMessage -ErrorAction SilentlyContinue)
    if (-not $canEmail) {
        Write-Log -Level 'WARN' -Message "Send-MailMessage not available. Skipping email."
    } else {
        try {
            $body = Get-Content -LiteralPath $script:LogFile -Raw
            $params = @{
                From       = $emailCfg.From
                To         = $emailCfg.To -join ','
                Subject    = "RVTools Daily Report - $(Get-Date -Format 'yyyy-MM-dd')"
                Body       = $body
                SmtpServer = $emailCfg.SmtpServer
            }
            if ($emailCfg.Port) { $params.Port = [int]$emailCfg.Port }
            if ($emailCfg.UseSsl) { $params.UseSsl = $true }
            Send-MailMessage @params
            Write-Log -Level 'SUCCESS' -Message "Summary email sent to $($emailCfg.To -join ', ')"
        } catch {
            $err = $_
            Write-Log -Level 'ERROR' -Message "Failed to send email: $($err.Exception.Message)"
        }
    }
} else {
    Write-Log -Message "Email disabled or suppressed."
}

Write-Log -Message ("Run complete. Summary: {0}" -f ($overallStatus -join '; '))

