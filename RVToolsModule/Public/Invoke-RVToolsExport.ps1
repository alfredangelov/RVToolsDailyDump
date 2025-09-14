function Invoke-RVToolsExport {
    <#
    .SYNOPSIS
        Main RVTools export cmdlet that orchestrates all export operations across VMware vCenter environments.

    .DESCRIPTION
        Invoke-RVToolsExport is the primary cmdlet for automating RVTools data exports from VMware vCenter servers.
        It provides a unified interface supporting both single server and bulk operations, with advanced features
        including chunked exports for large environments and secure credential management.
        and comprehensive error handling with detailed logging.

        Key Features:
        - Automated exports from multiple vCenter servers
        - Chunked export mode for large environments (exports individual tabs then merges)
        - Secure credential management using PowerShell SecretManagement
        - Comprehensive logging and error handling
        - Dry-run mode for testing configurations
        - Pipeline support for bulk operations
        - Flexible configuration through PSD1 files

    .PARAMETER ConfigPath
        Path to a PSD1 configuration file containing RVTools settings, export preferences, 
        and email configuration. Defaults to 'shared/Configuration.psd1'.
        The configuration file supports templates for easy setup in new environments.

    .PARAMETER HostListPath
        Path to a PSD1 host list file containing vCenter server definitions with connection details.
        Defaults to 'shared/HostList.psd1'. Each host entry should include hostname, optional username,
        and authentication preferences.

    .PARAMETER HostName
        Specifies a single vCenter server to export, overriding the server list from HostListPath.
        Must be a valid hostname or IP address of a vCenter server. When specified, only this server
        will be processed regardless of what's configured in the host list.

    .PARAMETER Username
        Username for vCenter authentication that overrides the default username in configuration.
        This parameter allows per-execution credential override without modifying configuration files.
        Credentials will still be retrieved from SecretManagement vault using the specified username.

    .PARAMETER ExportMode
        Defines the export strategy to use. Valid values:
        - Normal: Standard RVTools export with all tabs in a single operation (default)
        - Chunked: Exports each tab individually then merges into consolidated Excel file
        - {TabName}: Export a single specific tab (e.g., 'vLicense', 'vInfo', 'vHost')
        Use Chunked mode for large environments where standard exports might timeout.
        Use single tab names for lightweight testing or targeted data collection.

    .PARAMETER ChunkedExport
        Forces chunked export mode for all servers, equivalent to setting ExportMode to 'Chunked'.
        This switch parameter provides a convenient way to enable chunked exports without 
        specifying the ExportMode parameter explicitly.

    .PARAMETER NoEmail
        Bypasses email notification sending even if email configuration is present and enabled.
        This parameter overrides any email settings in the configuration file and is useful for
        scheduled runs where email notifications are not desired or for testing purposes.

    .PARAMETER DryRun
        Runs the cmdlet in dry-run mode without executing actual RVTools commands or file operations.
        This mode is useful for testing configurations, validating credentials, and previewing operations
        without making any changes. All logging output will be prefixed with "[Dry-Run]" and template
        configurations will be automatically used.

    .OUTPUTS
        System.Management.Automation.PSCustomObject[]
        Returns an array of result objects, one for each processed server, with the following properties:
        - HostName: The vCenter server that was processed
        - Success: Boolean indicating if the export completed successfully
        - ExportFile: Full path to the generated export file
        - ExitCode: RVTools exit code (0 = success)
        - Message: Descriptive message about the operation result
        - SuccessfulTabs: (Chunked mode only) Number of tabs exported successfully
        - FailedTabs: (Chunked mode only) Number of tabs that failed to export
        - FailedTabDetails: (Chunked mode only) Array of failed tab details

    .EXAMPLE
        Invoke-RVToolsExport

        Description
        -----------
        Runs export using all servers from the host list configuration file with default settings.
        Uses normal export mode and sends email notifications if configured.

    .EXAMPLE
        Invoke-RVToolsExport -DryRun

        Description
        -----------
        Runs in dry-run mode to test configuration without executing actual exports.
        Automatically uses template configuration files and skips all external operations.
        Useful for validating setup before running actual exports.

    .EXAMPLE
        Invoke-RVToolsExport -HostName "vcenter01.domain.com" -ChunkedExport

        Description
        -----------
        Exports data from a specific vCenter server using chunked mode, overriding the host list.
        Each RVTools tab will be exported separately then merged into a single Excel file.

    .EXAMPLE
        Invoke-RVToolsExport -ExportMode Chunked -NoEmail

        Description
        -----------
        Exports all configured servers using chunked mode without sending email notifications.
        Useful for large environments where standard exports might fail due to timeouts.

    .EXAMPLE
        Invoke-RVToolsExport -Username "backup-admin" -ConfigPath "C:\Custom\Config.psd1"

        Description
        -----------
        Uses a custom configuration file and specific username for authentication.
        Credentials for 'backup-admin' will be retrieved from SecretManagement vault.

    .EXAMPLE
        $results = Invoke-RVToolsExport -DryRun
        $results | Where-Object { -not $_.Success } | Select-Object HostName, Message

        Description
        -----------
        Captures results from dry-run and filters to show only failed exports with their error messages.
        Useful for troubleshooting configuration issues before running actual exports.

    .NOTES
        Prerequisites:
        - RVTools must be installed (default location: C:\Program Files (x86)\Dell\RVTools\RVTools.exe)
        - PowerShell SecretManagement and SecretStore modules must be installed
        - Valid configuration files (Configuration.psd1 and HostList.psd1) must be present
        - vCenter credentials must be stored in SecretManagement vault
        - For chunked exports: Excel must be installed for COM object access

        Configuration Files:
        The cmdlet uses two main configuration files in the 'shared' directory:
        - Configuration.psd1: Main settings including paths and email configuration
        - HostList.psd1: List of vCenter servers and their connection details
        
        Template versions of these files (*-Template.psd1) are used automatically in dry-run mode
        or when the main configuration files are not found.

        Credential Management:
        vCenter credentials are securely stored using PowerShell SecretManagement.
        Use the Set-RVToolsCredentials.ps1 script to configure credentials before first use.
        Credentials are encrypted and stored in the local user's SecretStore vault.

        Author: Alfred Angelov
        Version: 2.1.0
        
    .LINK
        https://www.dell.com/support/home/en-us/product-support/product/rvtools

    .LINK
        https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.secretmanagement/
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter()]
        [string]$ConfigPath = (Join-Path $PSScriptRoot '../../shared/Configuration.psd1'),
        
        [Parameter()]
        [string]$HostListPath = (Join-Path $PSScriptRoot '../../shared/HostList.psd1'),
        
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('ComputerName', 'Server', 'vCenter')]
        [string]$HostName,
        
        [Parameter()]
        [string]$Username,
        
        [Parameter()]
        [string]$ExportMode = 'Normal',
        
        [Parameter()]
        [string[]]$CustomTabs,
        
        [Parameter()]
        [switch]$ChunkedExport,
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [switch]$NoEmail,
        
        [Parameter()]
        [switch]$DryRun
    )
    
    # Parameter validation
    if ($ExportMode -eq 'Custom' -and (-not $CustomTabs -or $CustomTabs.Count -eq 0)) {
        throw "CustomTabs parameter is required when ExportMode is set to 'Custom'."
    }
    
    if ($CustomTabs -and $ExportMode -ne 'Custom') {
        Write-Warning "CustomTabs parameter specified but ExportMode is not 'Custom'. CustomTabs will be ignored."
    }
    
    # Validate ExportMode - check if it's a valid tab name
    $validExportModes = @('Normal', 'Chunked', 'InfoOnly', 'Custom')
    $tabDefinitions = Get-RVToolsTabDefinitions
    $validTabNames = $tabDefinitions | ForEach-Object { $_.FileName }
    
    if ($ExportMode -notin $validExportModes -and $ExportMode -notin $validTabNames) {
        $availableTabs = $validTabNames -join "', '"
        throw "Invalid ExportMode '$ExportMode'. Valid options are: 'Normal', 'Chunked', 'InfoOnly', 'Custom', or a specific tab name like '$availableTabs'."
    }
    
    # Determine if this is a single-tab export
    $isSingleTabExport = $ExportMode -in $validTabNames
    
    # Import SecretManagement module if available and using SecretManagement auth
    try {
        if (-not $DryRun) {
            Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
            Write-Verbose "SecretManagement module loaded successfully"
        }
    } catch {
        Write-Warning "SecretManagement module not available. Falling back to prompt authentication."
    }

    # Load configuration
    $configResult = Import-RVToolsConfiguration -ConfigPath $ConfigPath -HostListPath $HostListPath -PreferTemplate:$DryRun -ScriptRoot (Split-Path $PSScriptRoot -Parent)
    $cfg = $configResult.Configuration
    $usingTemplateCfg = $configResult.UsingTemplateConfig
    $DryRun = $DryRun -or $usingTemplateCfg

    # Set up logging configuration
    $script:ConfigLogLevel = $cfg.Logging?.LogLevel ?? 'INFO'

    # Resolve paths
    $rvtoolsPath  = Resolve-RVToolsPath -Path ($cfg.RVToolsPath) -ScriptRoot (Split-Path $PSScriptRoot -Parent)
    $exportsRoot  = Resolve-RVToolsPath -Path (($cfg.ExportFolder) ?? 'exports') -ScriptRoot (Split-Path $PSScriptRoot -Parent)
    $logsRoot     = Resolve-RVToolsPath -Path (($cfg.LogsFolder) ?? 'logs') -ScriptRoot (Split-Path $PSScriptRoot -Parent)

    New-RVToolsDirectory -Path $exportsRoot | Out-Null
    New-RVToolsDirectory -Path $logsRoot | Out-Null

    $script:LogFile = Join-Path $logsRoot ("RVTools_RunLog_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

    if (-not $DryRun) {
        if (-not (Test-Path -LiteralPath $rvtoolsPath)) {
            throw "RVTools executable not found at '$rvtoolsPath'. Update RVToolsPath in the configuration."
        }
    } else {
        Write-RVToolsLog -Level 'WARN' -Message "Dry-run mode: RVTools path check skipped." -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
    }

    # Determine servers to process
    if ($HostName) {
        # Single server mode
        $servers = @([pscustomobject]@{ 
            Name = $HostName
            Username = $Username ?? $cfg.Auth?.Username
            ExportMode = $ExportMode
        })
    } else {
        # Multi-server mode from host list
        $hostItems = $configResult.HostList?.Hosts
        if (-not $hostItems) { 
            throw "Host list is empty in '$($configResult.HostListPath)'" 
        }

        # Normalize host entries
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
    }

    if (-not $servers) { throw "No valid servers found." }

    # Auth settings
    $authMethod = ($cfg.Auth?.Method ?? 'Prompt')
    $defaultUsername = $cfg.Auth?.Username
    $vaultName = $cfg.Auth?.DefaultVault ?? 'RVToolsVault'
    $secretPattern = $cfg.Auth?.SecretNamePattern ?? '{HostName}-{Username}'
    $usePasswordEncryption = $cfg.Auth?.UsePasswordEncryption ?? $true
    $extraArgs = @()
    if ($cfg.RVToolsArgs) { $extraArgs += [string[]]$cfg.RVToolsArgs }

    # Cache credentials by username
    $credCache = @{}
    function Get-CredForUser {
        param(
            [Parameter(Mandatory)] [string] $Username,
            [Parameter(Mandatory)] [string] $HostName
        )
        
        $cacheKey = "$HostName-$Username"
        if ($credCache.ContainsKey($cacheKey)) { 
            Write-RVToolsLog -Level 'DEBUG' -Message "Using cached credential for $Username on $HostName" -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
            return $credCache[$cacheKey] 
        }
        
        $cred = Get-RVToolsCredentialFromVault -HostName $HostName -Username $Username -VaultName $vaultName -SecretPattern $secretPattern -AuthMethod $authMethod -DryRun:$DryRun
        
        if ($cred) {
            $credCache[$cacheKey] = $cred
        }
        
        return $cred
    }

    $results = @()

    foreach ($server in $servers) {
        $name = $server.Name
        $user = if ($server.Username) { $server.Username } elseif ($defaultUsername) { $defaultUsername } else { '' }
        $serverExportMode = if ($server.ExportMode) { $server.ExportMode } else { 'Normal' }
        
        # Determine export mode type
        $useChunkedExport = $ChunkedExport -or ($serverExportMode -eq 'Chunked')
        $useSingleTabExport = $serverExportMode -in $validTabNames
        
        Write-RVToolsLog -Message "Processing $name with export mode: $serverExportMode" -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel

        if (-not $DryRun) {
            if ([string]::IsNullOrWhiteSpace($user) -and $authMethod -eq 'Prompt') {
                # Ask for username interactively once per server
                $user = Read-Host -Prompt "Enter username for $name"
            }
        }

        if ([string]::IsNullOrWhiteSpace($user)) {
            Write-RVToolsLog -Level 'WARN' -Message "Skipping $name because no username provided." -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
            continue
        }

        $cred = $null
        if (-not $DryRun) {
            $cred = Get-CredForUser -Username $user -HostName $name
        }

        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $exportFileName = "{0}-{1}.xlsx" -f $name, $timestamp
        $baseFileName = "{0}-{1}" -f $name, $timestamp

        if ($useSingleTabExport) {
            # Single-tab export mode
            $result = Invoke-RVToolsSingleTabExport -HostName $name -Credential $cred -RVToolsPath $rvtoolsPath -ExportDirectory $exportsRoot -TabName $serverExportMode -BaseFileName $baseFileName -UsePasswordEncryption:$usePasswordEncryption -ExtraArgs $extraArgs -DryRun:$DryRun -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
            
            if ($result) {
                $results += $result
                
                if ($result.Success) {
                    Write-RVToolsLog -Level 'SUCCESS' -Message $result.Message -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
                } else {
                    Write-RVToolsLog -Level 'ERROR' -Message $result.Message -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
                }
            } else {
                Write-RVToolsLog -Level 'ERROR' -Message "No result returned from single-tab export for $name" -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
            }
        } elseif ($useChunkedExport) {
            # Chunked export mode
            $result = Invoke-RVToolsChunkedExport -HostName $name -Credential $cred -RVToolsPath $rvtoolsPath -ExportDirectory $exportsRoot -BaseFileName $baseFileName -UsePasswordEncryption:$usePasswordEncryption -ExtraArgs $extraArgs -DryRun:$DryRun -TestMode:$TestMode -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
            
            if ($result) {
                $results += $result
                
                if ($result.Success) {
                    if ($result.FailedTabs -eq 0) {
                        Write-RVToolsLog -Level 'SUCCESS' -Message $result.Message -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
                    } else {
                        Write-RVToolsLog -Level 'SUCCESS' -Message $result.Message -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
                    }
                } else {
                    Write-RVToolsLog -Level 'ERROR' -Message $result.Message -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
                }
            } else {
                Write-RVToolsLog -Level 'ERROR' -Message "No result returned from chunked export for $name" -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
            }
        } else {
            # Standard export mode
            $result = Invoke-RVToolsStandardExport -HostName $name -Credential $cred -RVToolsPath $rvtoolsPath -ExportDirectory $exportsRoot -ExportFileName $exportFileName -UsePasswordEncryption:$usePasswordEncryption -ExtraArgs $extraArgs -DryRun:$DryRun -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
            
            if ($result) {
                $results += $result
                
                if ($result.Success) {
                    Write-RVToolsLog -Level 'SUCCESS' -Message $result.Message -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
                } else {
                    Write-RVToolsLog -Level 'ERROR' -Message $result.Message -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
                }
            } else {
                Write-RVToolsLog -Level 'ERROR' -Message "No result returned from standard export for $name" -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
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
                    Write-RVToolsLog -Level 'ERROR' -Message "Microsoft Graph email requires TenantId and ClientId in configuration." -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
                } elseif ([string]::IsNullOrWhiteSpace($emailCfg['ClientSecret']) -and [string]::IsNullOrWhiteSpace($emailCfg['ClientSecretName'])) {
                    Write-RVToolsLog -Level 'ERROR' -Message "Microsoft Graph email requires either ClientSecret or ClientSecretName in configuration." -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
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
                    
                    $graphParams.LogFile = $script:LogFile
                    $graphParams.ConfigLogLevel = $script:ConfigLogLevel
                    
                    $success = Send-RVToolsGraphEmail @graphParams
                    if ($success) {
                        Write-RVToolsLog -Level 'SUCCESS' -Message "Summary email sent via Microsoft Graph to $($emailCfg.To -join ', ')" -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
                    } else {
                        Write-RVToolsLog -Level 'ERROR' -Message "Failed to send email via Microsoft Graph (see previous error)" -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
                    }
                }
            } else {
                # Traditional SMTP method
                $canEmail = $null -ne (Get-Command -Name Send-MailMessage -ErrorAction SilentlyContinue)
                if (-not $canEmail) {
                    Write-RVToolsLog -Level 'WARN' -Message "Send-MailMessage not available. Skipping email." -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
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
                    Write-RVToolsLog -Level 'SUCCESS' -Message "Summary email sent via SMTP to $($emailCfg.To -join ', ')" -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
                }
            }
        } catch {
            $err = $_
            Write-RVToolsLog -Level 'ERROR' -Message "Failed to send email: $($err.Exception.Message)" -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
        }
    } else {
        Write-RVToolsLog -Message "Email disabled or suppressed." -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel
    }

    # Summary
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

    Write-RVToolsLog -Message ("Run complete. Summary: {0}" -f ($overallStatus -join '; ')) -LogFile $script:LogFile -ConfigLogLevel $script:ConfigLogLevel

    return $results
}
