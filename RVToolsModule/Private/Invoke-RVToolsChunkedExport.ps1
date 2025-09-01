function Invoke-RVToolsChunkedExport {
    <#
    .SYNOPSIS
        Performs chunked RVTools export for large environments.

    .DESCRIPTION
        This function exports RVTools data in individual tabs to handle large
        environments that crash during full export, then merges the results.

    .PARAMETER HostName
        vCenter server hostname.

    .PARAMETER Credential
        PSCredential object for vCenter authentication.

    .PARAMETER RVToolsPath
        Path to RVTools executable.

    .PARAMETER ExportDirectory
        Directory for export files.

    .PARAMETER BaseFileName
        Base filename for exports (without extension).

    .PARAMETER UsePasswordEncryption
        Whether to use RVTools password encryption.

    .PARAMETER ExtraArgs
        Additional arguments to pass to RVTools.

    .PARAMETER DryRun
        Simulate the export without actually running RVTools.

    .EXAMPLE
        Invoke-RVToolsChunkedExport -HostName "vcenter.local" -Credential $cred -RVToolsPath "C:\RVTools\RVTools.exe" -ExportDirectory "C:\exports" -BaseFileName "vcenter-export"

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
        [string]$BaseFileName,
        
        [Parameter()]
        [switch]$UsePasswordEncryption,
        
        [Parameter()]
        [string[]]$ExtraArgs = @(),
        
        [Parameter()]
        [switch]$DryRun
    )
    
    Write-RVToolsLog -Message "Starting chunked export for $HostName" -Level 'INFO'
    
    $finalExportFile = Join-Path $ExportDirectory "$BaseFileName.xlsx"
    $tempFiles = @()
    $successfulTabs = @()
    $failedTabs = @()
    
    # Get RVTools tab definitions
    $rvToolsTabs = Get-RVToolsTabDefinitions
    
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
    
    foreach ($tab in $rvToolsTabs) {
        $tabFileName = "$BaseFileName-$($tab.FileName).xlsx"
        $tabFile = Join-Path $ExportDirectory $tabFileName
        
        $rvToolsArgs = if (-not $DryRun -and $Credential) {
            @('-c', $tab.Command, '-s', $HostName, '-u', $Credential.UserName, '-p', $passwordArg, '-d', "`"$ExportDirectory`"", '-f', $tabFileName) + $ExtraArgs
        } else {
            $simUser = if ($Credential) { $Credential.UserName } else { '<username>' }
            @('-c', $tab.Command, '-s', $HostName, '-u', $simUser, '-p', $passwordArg, '-d', "`"$ExportDirectory`"", '-f', $tabFileName) + $ExtraArgs
        }
        
        try {
            if ($PSCmdlet.ShouldProcess($HostName, "Export $($tab.FileName) tab")) {
                if (-not $DryRun) {
                    Write-RVToolsLog -Message "Exporting $($tab.FileName) tab for $HostName" -Level 'DEBUG'
                    
                    # Change to RVTools directory
                    $originalLocation = Get-Location
                    Set-Location (Split-Path $RVToolsPath -Parent)
                    
                    try {
                        $process = Start-Process -FilePath $RVToolsPath -ArgumentList $rvToolsArgs -NoNewWindow -Wait -PassThru
                        $code = $process.ExitCode
                        
                        if ($code -eq 0) {
                            Write-RVToolsLog -Message "Successfully exported $($tab.FileName) tab for $HostName" -Level 'DEBUG'
                            if (Test-Path $tabFile) {
                                $tempFiles += $tabFile
                                $successfulTabs += $tab.FileName
                            }
                        } elseif ($code -eq -1) {
                            Write-RVToolsLog -Message "Failed to export $($tab.FileName) tab for $HostName (connection failed)" -Level 'WARN'
                            $failedTabs += "$($tab.FileName) (connection failed)"
                        } elseif ($code -eq -1073741819) {
                            Write-RVToolsLog -Message "Failed to export $($tab.FileName) tab for $HostName (crash/memory issue)" -Level 'WARN'
                            $failedTabs += "$($tab.FileName) (crash)"
                        } else {
                            Write-RVToolsLog -Message "Failed to export $($tab.FileName) tab for $HostName (exit code $code)" -Level 'WARN'
                            $failedTabs += "$($tab.FileName) (exit $code)"
                        }
                    } finally {
                        Set-Location $originalLocation
                    }
                } else {
                    Write-RVToolsLog -Message "[Dry-Run] Would export $($tab.FileName): $RVToolsPath $($rvToolsArgs -join ' ')" -Level 'INFO'
                    $tempFiles += $tabFile  # Simulate file creation for dry run
                    $successfulTabs += $tab.FileName
                }
            }
        } catch {
            Write-RVToolsLog -Message "Exception while exporting $($tab.FileName) tab for ${HostName}: $($_.Exception.Message)" -Level 'ERROR'
            $failedTabs += "$($tab.FileName) (exception)"
        }
    }
    
    Write-RVToolsLog -Message "Tab export summary for $HostName - Successful: $($successfulTabs.Count), Failed: $($failedTabs.Count)" -Level 'INFO'
    if ($failedTabs.Count -gt 0) {
        Write-RVToolsLog -Message "Failed tabs: $($failedTabs -join ', ')" -Level 'WARN'
    }
    
    # Merge all tab files into final export file
    $mergeSucceeded = $false
    if ($tempFiles.Count -gt 0) {
        if (-not $DryRun) {
            # Filter to only files that actually exist
            $existingTempFiles = $tempFiles | Where-Object { Test-Path $_ }
            
            if ($existingTempFiles.Count -gt 0) {
                Write-RVToolsLog -Message "Found $($existingTempFiles.Count) successful tab exports out of $($tempFiles.Count) attempted" -Level 'INFO'
                $mergeSucceeded = Merge-RVToolsExcelFiles -SourceFiles $existingTempFiles -DestinationFile $finalExportFile
                
                if ($mergeSucceeded) {
                    # Clean up ALL tab files for this timestamp, including failed/stub files
                    $cleanupPattern = "$BaseFileName-*.xlsx"
                    $allTabFiles = Get-ChildItem -Path $ExportDirectory -Filter $cleanupPattern
                    foreach ($tabFileToClean in $allTabFiles) {
                        if ($tabFileToClean.FullName -ne $finalExportFile) {
                            try {
                                Remove-Item $tabFileToClean.FullName -Force
                                Write-RVToolsLog -Message "Cleaned up tab file: $($tabFileToClean.Name)" -Level 'DEBUG'
                            } catch {
                                Write-RVToolsLog -Message "Failed to remove tab file $($tabFileToClean.Name): $($_.Exception.Message)" -Level 'WARN'
                            }
                        }
                    }
                }
            }
        } else {
            Write-RVToolsLog -Message "[Dry-Run] Would merge $($tempFiles.Count) tab files into $finalExportFile" -Level 'INFO'
            $mergeSucceeded = $true  # Simulate success for dry run
        }
    }
    
    # Return result object
    return [pscustomobject]@{
        HostName = $HostName
        Success = $mergeSucceeded
        SuccessfulTabs = $successfulTabs.Count
        FailedTabs = $failedTabs.Count
        FailedTabDetails = $failedTabs
        ExportFile = if ($mergeSucceeded) { $finalExportFile } else { $null }
        Message = if ($mergeSucceeded) {
            if ($failedTabs.Count -eq 0) {
                "Completed chunked export"
            } else {
                "Completed partial chunked export ($($successfulTabs.Count)/$($rvToolsTabs.Count) tabs)"
            }
        } else {
            "Failed chunked export"
        }
    }
}
