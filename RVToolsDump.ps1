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
    Version: 2.0.1
    - Keep live config files out of source control. Templates are provided under `shared/`.
    - Credentials are requested securely at runtime. Password is passed to RVTools as plain text
      command-line argument (required by RVTools). Use a low-privilege service account.
    - PowerShell 7+ compatible.
    - New in v2.0.1: ImportExcel module integration - no Microsoft Excel installation required.
    - New in v2.0.1: ImportExcel module integration replacing Excel COM automation for chunked exports.
    - New in v2.0.0: Complete PowerShell module architecture with professional features.
    - New in v1.4.2: Unique log files per run (YYYYMMDD_HHMMSS format) for cleaner email reports.
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

# Import RVTools module for common functions
try {
    Import-Module (Join-Path $PSScriptRoot 'RVToolsModule') -Force -ErrorAction Stop
    Write-Verbose "RVToolsModule loaded successfully"
} catch {
    Write-Error "Failed to load RVToolsModule: $($_.Exception.Message)"
    exit 1
}

# Import SecretManagement module if available and using SecretManagement auth
try {
    if (-not $DryRun) {
        Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
        Write-Verbose "SecretManagement module loaded successfully"
    }
} catch {
    Write-Warning "SecretManagement module not available. Falling back to prompt authentication."
}

# Load configuration (prefer live file; fall back to template for discovery)
$configResult = Import-RVToolsConfiguration -ConfigPath $ConfigPath -HostListPath $HostListPath -PreferTemplate:$DryRun -ScriptRoot $PSScriptRoot
$cfg = $configResult.Configuration
$usingTemplateCfg = $configResult.UsingTemplateConfig
$DryRun = $DryRun -or $usingTemplateCfg

# Set up logging configuration
$script:ConfigLogLevel = $cfg.Logging?.LogLevel ?? 'INFO'

# Resolve paths
$rvtoolsPath  = Resolve-RVToolsPath -Path ($cfg.RVToolsPath) -ScriptRoot $PSScriptRoot
$exportsRoot  = Resolve-RVToolsPath -Path (($cfg.ExportFolder) ?? 'exports') -ScriptRoot $PSScriptRoot
$logsRoot     = Resolve-RVToolsPath -Path (($cfg.LogsFolder) ?? 'logs') -ScriptRoot $PSScriptRoot

New-RVToolsDirectory -Path $exportsRoot
New-RVToolsDirectory -Path $logsRoot

$script:LogFile = Join-Path $logsRoot ("RVTools_RunLog_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$script:ConfigLogLevel = $cfg.Logging?.LogLevel ?? 'INFO'

function Write-Log {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','DEBUG')] [string] $Level = 'INFO'
    )
    
    Write-RVToolsLog -Message $Message -Level $Level -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
}

if (-not $DryRun) {
    if (-not (Test-Path -LiteralPath $rvtoolsPath)) {
        throw "RVTools executable not found at '$rvtoolsPath'. Update RVToolsPath in the configuration."
    }
} else {
    Write-Log -Level 'WARN' -Message "Dry-run mode: RVTools path check skipped."
}

# Load host list
$hostItems = $configResult.HostList?.Hosts

if (-not $hostItems) { 
    throw "Host list is empty in '$($configResult.HostListPath)'" 
}

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

function Get-RVToolsEncryptedPasswordLocal {
    param(
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential] $Credential
    )
    
    return Get-RVToolsEncryptedPassword -Credential $Credential
}

function Get-SecretNameLocal {
    param(
        [Parameter(Mandatory)] [string] $HostName,
        [Parameter(Mandatory)] [string] $Username,
        [Parameter(Mandatory)] [string] $Pattern
    )
    return Get-RVToolsSecretName -HostName $HostName -Username $Username -Pattern $Pattern
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
    
    $cred = Get-RVToolsCredentialFromVault -HostName $HostName -Username $Username -VaultName $vaultName -SecretPattern $secretPattern -AuthMethod $authMethod -DryRun:$DryRun
    
    if ($cred) {
        $credCache[$cacheKey] = $cred
    }
    
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

function Send-MicrosoftGraphEmail {
    param(
        [Parameter(Mandatory)] [string] $TenantId,
        [Parameter(Mandatory)] [string] $ClientId,
        [Parameter()] [string] $ClientSecret,
        [Parameter()] [string] $ClientSecretName,
        [Parameter()] [string] $VaultName = 'RVToolsVault',
        [Parameter(Mandatory)] [string] $From,
        [Parameter(Mandatory)] [string[]] $To,
        [Parameter(Mandatory)] [string] $Subject,
        [Parameter(Mandatory)] [string] $Body
    )
    
    try {
        # Resolve ClientSecret from vault if ClientSecretName is provided
        if ($ClientSecretName -and -not $ClientSecret) {
            try {
                $ClientSecret = Get-Secret -Name $ClientSecretName -Vault $VaultName -AsPlainText -ErrorAction Stop
                Write-Log -Level 'DEBUG' -Message "Retrieved ClientSecret from vault: $ClientSecretName"
            } catch {
                Write-Log -Level 'ERROR' -Message "Failed to retrieve ClientSecret from vault '$VaultName' with name '$ClientSecretName': $($_.Exception.Message)"
                return $false
            }
        }
        
        # Validate that we have a ClientSecret
        if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
            Write-Log -Level 'ERROR' -Message "ClientSecret is required but not provided or retrieved from vault"
            return $false
        }
        
        # Import required modules
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        Import-Module Microsoft.Graph.Mail -ErrorAction Stop
        
        # Create client secret credential
        $SecureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $ClientSecretCredential = New-Object System.Management.Automation.PSCredential($ClientId, $SecureSecret)
        
        # Connect to Microsoft Graph
        Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -NoWelcome
        
        # Create the email message
        $BodyObject = @{
            ContentType = "Text"
            Content = $Body
        }
        
        $ToRecipients = @()
        foreach ($recipient in $To) {
            $ToRecipients += @{
                EmailAddress = @{
                    Address = $recipient
                }
            }
        }
        
        $Message = @{
            Subject = $Subject
            Body = $BodyObject
            ToRecipients = $ToRecipients
        }
        
        # Send the email
        Send-MgUserMail -UserId $From -Message $Message
        
        # Disconnect from Microsoft Graph
        Disconnect-MgGraph | Out-Null
        
        return $true
        
    } catch {
        Write-Log -Level 'ERROR' -Message "Microsoft Graph email error: $($_.Exception.Message)"
        try { Disconnect-MgGraph | Out-Null } catch { }
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
            $passwordArg = Get-RVToolsEncryptedPasswordLocal -Credential $cred
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
            
            $rvToolsArgs = if (-not $DryRun) {
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
                            $process = Start-Process -FilePath $rvtoolsPath -ArgumentList $rvToolsArgs -NoNewWindow -Wait -PassThru
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
                        Write-Log -Message "[Dry-Run] Would export $($tab.FileName): $rvtoolsPath $($rvToolsArgs -join ' ')"
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
                    # Use module function for Excel merging (ImportExcel-based, no Excel installation required)
                    $mergeSucceeded = Merge-RVToolsExcelFiles -SourceFiles $existingTempFiles -DestinationFile $exportFile
                    
                    # Clean up ALL tab files for this timestamp, including failed/stub files (regardless of merge success)
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
                    
                    if ($mergeSucceeded) {
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
                    
                    # Clean up any remaining tab files even if no successful exports
                    $allTabPattern = "{0}-{1}-*.xlsx" -f $name, $timestamp
                    $allTabFiles = Get-ChildItem -Path $exportsRoot -Filter $allTabPattern
                    foreach ($tabFile in $allTabFiles) {
                        try {
                            Remove-Item $tabFile.FullName -Force
                            Write-Log -Level 'DEBUG' -Message "Cleaned up failed tab file: $($tabFile.Name)"
                        } catch {
                            Write-Log -Level 'WARN' -Message "Failed to remove tab file $($tabFile.Name): $($_.Exception.Message)"
                        }
                    }
                    
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
        $rvToolsArgs = if (-not $DryRun) {
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
                        $process = Start-Process -FilePath $rvtoolsPath -ArgumentList $rvToolsArgs -NoNewWindow -Wait -PassThru
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
                    Write-Log -Message "[Dry-Run] Would run: $rvtoolsPath $($rvToolsArgs -join ' ')"
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
    $body = Get-Content -LiteralPath $script:LogFile -Raw
    $subject = "RVTools Daily Report - $(Get-Date -Format 'yyyy-MM-dd')"
    
    # Determine email method
    $method = if ($emailCfg.Method) { $emailCfg.Method } else { 'SMTP' }  # Default to SMTP for backward compatibility
    
    try {
        if ($method -eq 'MicrosoftGraph') {
            # Microsoft Graph email method
            if (-not $emailCfg.TenantId -or -not $emailCfg.ClientId) {
                Write-Log -Level 'ERROR' -Message "Microsoft Graph email requires TenantId and ClientId in configuration."
            } elseif ([string]::IsNullOrWhiteSpace($emailCfg['ClientSecret']) -and [string]::IsNullOrWhiteSpace($emailCfg['ClientSecretName'])) {
                Write-Log -Level 'ERROR' -Message "Microsoft Graph email requires either ClientSecret or ClientSecretName in configuration."
            } else {
                # Prepare parameters for Microsoft Graph email
                $graphParams = @{
                    TenantId = $emailCfg.TenantId
                    ClientId = $emailCfg.ClientId
                    From = $emailCfg.From
                    To = $emailCfg.To
                    Subject = $subject
                    Body = $body
                }
                
                # Add ClientSecret or ClientSecretName
                if (-not [string]::IsNullOrWhiteSpace($emailCfg['ClientSecret'])) {
                    $graphParams.ClientSecret = $emailCfg['ClientSecret']
                } elseif (-not [string]::IsNullOrWhiteSpace($emailCfg['ClientSecretName'])) {
                    $graphParams.ClientSecretName = $emailCfg['ClientSecretName']
                    $graphParams.VaultName = $cfg.Auth.DefaultVault ?? 'RVToolsVault'
                }
                
                $success = Send-MicrosoftGraphEmail @graphParams
                if ($success) {
                    Write-Log -Level 'SUCCESS' -Message "Summary email sent via Microsoft Graph to $($emailCfg.To -join ', ')"
                } else {
                    Write-Log -Level 'ERROR' -Message "Failed to send email via Microsoft Graph (see previous error)"
                }
            }
        } else {
            # Traditional SMTP method
            $canEmail = $null -ne (Get-Command -Name Send-MailMessage -ErrorAction SilentlyContinue)
            if (-not $canEmail) {
                Write-Log -Level 'WARN' -Message "Send-MailMessage not available. Skipping email."
            } else {
                $params = @{
                    From       = $emailCfg.From
                    To         = $emailCfg.To -join ','
                    Subject    = $subject
                    Body       = $body
                    SmtpServer = $emailCfg.SmtpServer
                }
                if ($emailCfg.Port) { $params.Port = [int]$emailCfg.Port }
                if ($emailCfg.UseSsl) { $params.UseSsl = $true }
                Send-MailMessage @params
                Write-Log -Level 'SUCCESS' -Message "Summary email sent via SMTP to $($emailCfg.To -join ', ')"
            }
        }
    } catch {
        $err = $_
        Write-Log -Level 'ERROR' -Message "Failed to send email: $($err.Exception.Message)"
    }
} else {
    Write-Log -Message "Email disabled or suppressed."
}

Write-Log -Message ("Run complete. Summary: {0}" -f ($overallStatus -join '; '))

