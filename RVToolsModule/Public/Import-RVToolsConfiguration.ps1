function Import-RVToolsConfiguration {
    <#
    .SYNOPSIS
        Imports RVTools configuration from PSD1 files with template fallback support.

    .DESCRIPTION
        This function loads RVTools configuration and host list files, with automatic
        fallback to template files for discovery or dry-run scenarios.

    .PARAMETER ConfigPath
        Path to the configuration PSD1 file.

    .PARAMETER HostListPath
        Path to the host list PSD1 file.

    .PARAMETER PreferTemplate
        Use template files instead of live files (useful for dry-run scenarios).

    .PARAMETER ScriptRoot
        Root directory for resolving relative paths to template files.

    .EXAMPLE
        $config = Import-RVToolsConfiguration -ConfigPath "C:\RVTools\shared\Configuration.psd1"

    .EXAMPLE
        $config = Import-RVToolsConfiguration -ConfigPath ".\config.psd1" -HostListPath ".\hosts.psd1" -PreferTemplate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [Parameter()]
        [string]$HostListPath,
        
        [Parameter()]
        [switch]$PreferTemplate,
        
        [Parameter()]
        [string]$ScriptRoot = $PWD.Path
    )
    
    function Import-DataFileOrTemplate {
        param(
            [Parameter(Mandatory)] [string] $LivePath,
            [Parameter(Mandatory)] [string] $TemplateName,
            [Parameter(Mandatory)] [string] $Purpose,
            [Parameter(Mandatory)] [string] $ScriptRoot,
            [switch] $PreferTemplate
        )
        
        $templatePath = Join-Path $ScriptRoot ("shared/{0}" -f $TemplateName)
        
        if ($PreferTemplate -and (Test-Path -LiteralPath $templatePath)) {
            Write-RVToolsLog -Message "Using template $TemplateName for $Purpose (dry-run or preference)." -Level 'WARN'
            return [pscustomobject]@{ 
                Data = (Import-PowerShellDataFile -Path $templatePath)
                UsingTemplate = $true
                Path = $templatePath 
            }
        }
        
        if (Test-Path -LiteralPath $LivePath) {
            try {
                $data = Import-PowerShellDataFile -Path $LivePath
                return [pscustomobject]@{ 
                    Data = $data
                    UsingTemplate = $false
                    Path = $LivePath 
                }
            } catch {
                Write-RVToolsLog -Message "Failed to parse $Purpose at '$LivePath': $($_.Exception.Message)" -Level 'WARN'
                if (Test-Path -LiteralPath $templatePath) {
                    Write-RVToolsLog -Message "Falling back to template $TemplateName for $Purpose." -Level 'WARN'
                    return [pscustomobject]@{ 
                        Data = (Import-PowerShellDataFile -Path $templatePath)
                        UsingTemplate = $true
                        Path = $templatePath 
                    }
                }
                throw
            }
        } elseif (Test-Path -LiteralPath $templatePath) {
            Write-RVToolsLog -Message "Live $Purpose not found. Using template $TemplateName." -Level 'WARN'
            return [pscustomobject]@{ 
                Data = (Import-PowerShellDataFile -Path $templatePath)
                UsingTemplate = $true
                Path = $templatePath 
            }
        } else {
            throw "Neither live $Purpose ('$LivePath') nor template ('$templatePath') found."
        }
    }
    
    # Load configuration
    $cfgResult = Import-DataFileOrTemplate -LivePath $ConfigPath -TemplateName 'Configuration-Template.psd1' -Purpose 'configuration' -ScriptRoot $ScriptRoot -PreferTemplate:$PreferTemplate
    
    $result = [pscustomobject]@{
        Configuration = $cfgResult.Data
        UsingTemplateConfig = $cfgResult.UsingTemplate
        ConfigPath = $cfgResult.Path
        HostList = $null
        UsingTemplateHostList = $false
        HostListPath = $null
    }
    
    # Load host list if path provided
    if ($HostListPath) {
        $hostsResult = Import-DataFileOrTemplate -LivePath $HostListPath -TemplateName 'HostList-Template.psd1' -Purpose 'host list' -ScriptRoot $ScriptRoot -PreferTemplate:$PreferTemplate
        $result.HostList = $hostsResult.Data
        $result.UsingTemplateHostList = $hostsResult.UsingTemplate
        $result.HostListPath = $hostsResult.Path
    }
    
    return $result
}
