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

.NOTES
    - Keep live config files out of source control. Templates are provided under `shared/`.
    - Credentials are requested securely at runtime. Password is passed to RVTools as plain text
      command-line argument (required by RVTools). Use a low-privilege service account.
    - PowerShell 7+ compatible.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()] [string] $ConfigPath = (Join-Path $PSScriptRoot 'shared/Configuration.psd1'),
    [Parameter()] [string] $HostListPath = (Join-Path $PSScriptRoot 'shared/HostList.psd1'),
    [Parameter()] [switch] $NoEmail,
    [Parameter()] [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')] [string] $Level = 'INFO'
    )
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $line | Tee-Object -FilePath $script:LogFile -Append | Out-Host
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
$hostItems = $hostsResult.Data

if (-not $hostItems) { throw "Host list is empty in '$hostListFile'" }

# Normalize host entries into [pscustomobject] with Name + optional Username
$servers = @(
    foreach ($item in $hostItems) {
    switch ($item.GetType().Name) {
        'String'      { [pscustomobject]@{ Name = $item; Username = $null } }
        'Hashtable'   { [pscustomobject]@{ Name = $item.Name; Username = $item.Username } }
        'PSCustomObject' { [pscustomobject]@{ Name = $item.Name; Username = $item.Username } }
        default       { Write-Warning "Unsupported host list entry type: $($item.GetType().FullName)"; continue }
    }
    }
) | Where-Object { $_.Name }

if (-not $servers) { throw "No valid servers found in host list." }

# Auth settings
$authMethod = ($cfg.Auth?.Method ?? 'Prompt')
$defaultUsername = $cfg.Auth?.Username

# Cache credentials by username
$credCache = @{}
function Get-CredForUser {
    param([Parameter(Mandatory)] [string] $Username)
    if ($credCache.ContainsKey($Username)) { return $credCache[$Username] }
    $cred = Get-Credential -UserName $Username -Message "Enter password for $Username"
    $credCache[$Username] = $cred
    return $cred
}

$extraArgs = @()
if ($cfg.RVToolsArgs) { $extraArgs += [string[]]$cfg.RVToolsArgs }

$overallStatus = @()

foreach ($server in $servers) {
    $name = $server.Name
    $user = if ($server.Username) { $server.Username } elseif ($defaultUsername) { $defaultUsername } else { '' }

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
    $plainPwd = $null
    if (-not $DryRun) {
        $cred = Get-CredForUser -Username $user
        $plainPwd = $cred.GetNetworkCredential().Password
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $exportFile = Join-Path $exportsRoot ("{0}-{1}.xlsx" -f $name, $timestamp)

    $args = if (-not $DryRun) {
        @('-c', '-s', $name, '-u', $cred.UserName, '-p', $plainPwd, '-f', $exportFile) + $extraArgs
    } else {
        $simUser = if ($user) { $user } else { '<username>' }
        @('-c', '-s', $name, '-u', $simUser, '-p', '<redacted>', '-f', $exportFile) + $extraArgs
    }

    try {
        if ($PSCmdlet.ShouldProcess($name, 'Run RVTools export')) {
            if (-not $DryRun) {
                Write-Log -Message "Starting RVTools export for $name to $exportFile"
                & $rvtoolsPath @args
                $code = $LASTEXITCODE
                if ($code -eq 0) {
                    Write-Log -Level 'SUCCESS' -Message "Completed export for $name"
                    $overallStatus += "SUCCESS - $name"
                } else {
                    Write-Log -Level 'ERROR' -Message "RVTools exit code $code for $name"
                    $overallStatus += "FAILURE ($code) - $name"
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

