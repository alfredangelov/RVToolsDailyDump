function Invoke-RVToolsStandardExport {
    <#
    .SYNOPSIS
        Performs standard RVTools export for normal-sized environments.

    .DESCRIPTION
        This function exports all RVTools data in a single operation using
        the ExportAll2xlsx command for standard environments.

    .PARAMETER HostName
        vCenter server hostname.

    .PARAMETER Credential
        PSCredential object for vCenter authentication.

    .PARAMETER RVToolsPath
        Path to RVTools executable.

    .PARAMETER ExportDirectory
        Directory for export files.

    .PARAMETER ExportFileName
        Full filename for the export (with extension).

    .PARAMETER UsePasswordEncryption
        Whether to use RVTools password encryption.

    .PARAMETER ExtraArgs
        Additional arguments to pass to RVTools.

    .PARAMETER DryRun
        Simulate the export without actually running RVTools.

    .EXAMPLE
        Invoke-RVToolsStandardExport -HostName "vcenter.local" -Credential $cred -RVToolsPath "C:\RVTools\RVTools.exe" -ExportDirectory "C:\exports" -ExportFileName "vcenter-export.xlsx"

    .OUTPUTS
        System.Object - Result object with success status and details.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$HostName,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory)]
        [string]$RVToolsPath,
        
        [Parameter(Mandatory)]
        [string]$ExportDirectory,
        
        [Parameter(Mandatory)]
        [string]$ExportFileName,
        
        [Parameter()]
        [switch]$UsePasswordEncryption,
        
        [Parameter()]
        [string[]]$ExtraArgs = @(),
        
        [Parameter()]
        [switch]$DryRun
    )
    
    $exportFile = Join-Path $ExportDirectory $ExportFileName
    
    # Prepare password argument
    $passwordArg = if ($Credential -and -not $DryRun) {
        if ($UsePasswordEncryption) {
            Get-RVToolsEncryptedPassword -Credential $Credential
        } else {
            $Credential.GetNetworkCredential().Password
        }
    } else {
        if ($UsePasswordEncryption) { '<encrypted>' } else { '<redacted>' }
    }
    
    # Standard export mode - export all tabs at once
    $rvToolsArgs = if (-not $DryRun -and $Credential) {
        @('-c', 'ExportAll2xlsx', '-s', $HostName, '-u', $Credential.UserName, '-p', $passwordArg, '-d', "`"$ExportDirectory`"", '-f', $ExportFileName) + $ExtraArgs
    } else {
        $simUser = if ($Credential) { $Credential.UserName } else { '<username>' }
        @('-c', 'ExportAll2xlsx', '-s', $HostName, '-u', $simUser, '-p', $passwordArg, '-d', "`"$ExportDirectory`"", '-f', $ExportFileName) + $ExtraArgs
    }

    try {
        if ($PSCmdlet.ShouldProcess($HostName, 'Run RVTools export')) {
            if (-not $DryRun) {
                Write-RVToolsLog -Message "Starting RVTools export for $HostName to $exportFile" -Level 'INFO'
                
                # Change to RVTools directory (as recommended by Dell)
                $originalLocation = Get-Location
                Set-Location (Split-Path $RVToolsPath -Parent)
                
                try {
                    # Use Start-Process as recommended by Dell's official script
                    $process = Start-Process -FilePath $RVToolsPath -ArgumentList $rvToolsArgs -NoNewWindow -Wait -PassThru
                    $code = $process.ExitCode
                    
                    if ($code -eq 0) {
                        Write-RVToolsLog -Message "Completed export for $HostName" -Level 'SUCCESS'
                        return [pscustomobject]@{
                            HostName = $HostName
                            Success = $true
                            ExportFile = $exportFile
                            ExitCode = $code
                            Message = "SUCCESS"
                        }
                    } elseif ($code -eq -1) {
                        Write-RVToolsLog -Message "RVTools connection failed for $HostName (exit code -1)" -Level 'ERROR'
                        return [pscustomobject]@{
                            HostName = $HostName
                            Success = $false
                            ExportFile = $null
                            ExitCode = $code
                            Message = "CONNECTION FAILED"
                        }
                    } else {
                        Write-RVToolsLog -Message "RVTools exit code $code for $HostName" -Level 'ERROR'
                        return [pscustomobject]@{
                            HostName = $HostName
                            Success = $false
                            ExportFile = $null
                            ExitCode = $code
                            Message = "FAILURE ($code)"
                        }
                    }
                } finally {
                    # Restore original location
                    Set-Location $originalLocation
                }
            } else {
                Write-RVToolsLog -Message "[Dry-Run] Would run: $RVToolsPath $($rvToolsArgs -join ' ')" -Level 'INFO'
                return [pscustomobject]@{
                    HostName = $HostName
                    Success = $true
                    ExportFile = $exportFile
                    ExitCode = 0
                    Message = "DRYRUN"
                }
            }
        } else {
            # ShouldProcess returned false (user chose not to proceed)
            return [pscustomobject]@{
                HostName = $HostName
                Success = $false
                ExportFile = $null
                ExitCode = $null
                Message = "SKIPPED"
            }
        }
    } catch {
        $err = $_
        Write-RVToolsLog -Message "Exception while exporting ${HostName}: $($err.Exception.Message)" -Level 'ERROR'
        return [pscustomobject]@{
            HostName = $HostName
            Success = $false
            ExportFile = $null
            ExitCode = $null
            Message = "ERROR - $($err.Exception.Message)"
        }
    }
}
