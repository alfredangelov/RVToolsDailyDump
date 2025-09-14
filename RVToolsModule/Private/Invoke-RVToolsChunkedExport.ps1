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

    .PARAMETER TestMode
        Use a minimal set of 3 tabs (vInfo, vHost, vDatastore) for quick testing instead of all 26 tabs.

    .PARAMETER LogFile
        Path to log file for output.

    .PARAMETER ConfigLogLevel
        Log level configuration for filtering output.

    .EXAMPLE
        Invoke-RVToolsChunkedExport -HostName "vcenter.local" -Credential $cred -RVToolsPath "C:\RVTools\RVTools.exe" -ExportDirectory "C:\exports" -BaseFileName "vcenter-export"

    .EXAMPLE
        Invoke-RVToolsChunkedExport -HostName "vcenter.local" -Credential $cred -RVToolsPath "C:\RVTools\RVTools.exe" -ExportDirectory "C:\exports" -BaseFileName "vcenter-export" -TestMode

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
        [switch]$DryRun,
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [string]$LogFile,
        
        [Parameter()]
        [string]$ConfigLogLevel = 'INFO'
    )
    
    Write-RVToolsLog -Message "Starting chunked export for $HostName" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
    
    $finalExportFile = Join-Path $ExportDirectory "$BaseFileName.xlsx"
    
    # Create temporary subdirectory for tab files
    $tempSubDirectory = Join-Path $ExportDirectory $BaseFileName
    if (-not $DryRun) {
        try {
            New-Item -ItemType Directory -Path $tempSubDirectory -Force | Out-Null
            Write-RVToolsLog -Message "Created temporary subdirectory: $tempSubDirectory" -Level 'DEBUG' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        }
        catch {
            Write-RVToolsLog -Message "Failed to create temporary subdirectory: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
            return @{
                Success        = $false
                Error          = "Failed to create temporary subdirectory: $($_.Exception.Message)"
                Files          = @()
                SuccessfulTabs = 0
                FailedTabs     = 0
                HostName       = $HostName
                Message        = "Failed to create temporary subdirectory"
            }
        }
    }
    else {
        Write-RVToolsLog -Message "[DRY RUN] Would create temporary subdirectory: $tempSubDirectory" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
    }
    
    # Define tabs to export
    if ($TestMode) {
        Write-RVToolsLog -Message "TEST MODE: Using minimal tab set for quick testing" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        $rvToolsTabs = @(
            @{ Command = 'ExportvInfo2xlsx'; FileName = 'vInfo' },
            @{ Command = 'ExportvHost2xlsx'; FileName = 'vHost' },
            @{ Command = 'ExportvDatastore2xlsx'; FileName = 'vDatastore' }
        )
    }
    else {
        $rvToolsTabs = Get-RVToolsTabDefinitions
    }
    
    $exportedFiles = @()
    $totalTabs = $rvToolsTabs.Count
    $currentTab = 0
    
    # Prepare password argument
    $passwordArg = if ($Credential) {
        if ($UsePasswordEncryption) {
            Get-RVToolsEncryptedPassword -Credential $Credential
        }
        else {
            $Credential.GetNetworkCredential().Password
        }
    }
    else {
        ""
    }
    
    $logPasswordArg = if ($Credential) {
        if ($UsePasswordEncryption) { '<encrypted>' } else { '<redacted>' }
    }
    else {
        '<none>'
    }
    
    Write-RVToolsLog -Message "DEBUG: About to start foreach loop with $totalTabs tabs" -Level 'DEBUG' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
    
    foreach ($tab in $rvToolsTabs) {
        $currentTab++
        Write-RVToolsLog -Message "DEBUG: Processing tab $currentTab of $totalTabs : $($tab.FileName)" -Level 'DEBUG' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        
        $tabFileName = "$BaseFileName-$($tab.FileName).xlsx"
        $tabFile = Join-Path $tempSubDirectory $tabFileName
        
        $rvToolsArgs = if (-not $DryRun -and $Credential) {
            @('-c', $tab.Command, '-s', $HostName, '-u', $Credential.UserName, '-p', $passwordArg, '-d', "`"$tempSubDirectory`"", '-f', $tabFileName) + $ExtraArgs
        }
        else {
            $simUser = if ($Credential) { $Credential.UserName } else { '<username>' }
            @('-c', $tab.Command, '-s', $HostName, '-u', $simUser, '-p', $passwordArg, '-d', "`"$tempSubDirectory`"", '-f', $tabFileName) + $ExtraArgs
        }
        
        try {
            if ($PSCmdlet.ShouldProcess($HostName, "Export $($tab.FileName) tab")) {
                if (-not $DryRun) {
                    Write-RVToolsLog -Message "DEBUG: About to execute RVTools with args: $($rvToolsArgs -join ' ')" -Level 'DEBUG' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                    
                    $process = Start-Process -FilePath $RVToolsPath -ArgumentList $rvToolsArgs -Wait -PassThru -NoNewWindow
                    
                    Write-RVToolsLog -Message "DEBUG: RVTools process completed with exit code: $($process.ExitCode)" -Level 'DEBUG' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                    
                    if (Test-Path $tabFile) {
                        $exportedFiles += $tabFile
                        Write-RVToolsLog -Message "Successfully exported $($tab.FileName) tab" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                    }
                    else {
                        Write-RVToolsLog -Message "RVTools failed to create file for $($tab.FileName)" -Level 'WARN' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                    }
                }
                else {
                    Write-RVToolsLog -Message "[DRY RUN] Would export $($tab.FileName) to $tabFile" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                    $exportedFiles += $tabFile
                }
            }
        }
        catch {
            Write-RVToolsLog -Message "Exception during $($tab.FileName) export: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        }
        
        Write-RVToolsLog -Message "DEBUG: Completed processing tab: $($tab.FileName)" -Level 'DEBUG' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
    }
    
    Write-RVToolsLog -Message "DEBUG: Completed processing all tabs. Found $($exportedFiles.Count) files" -Level 'DEBUG' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
    
    if ($exportedFiles.Count -eq 0) {
        Write-RVToolsLog -Message "No files were successfully exported" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        return @{
            Success        = $false
            Error          = "No files were successfully exported"
            Files          = @()
            SuccessfulTabs = 0
            FailedTabs     = $totalTabs
            HostName       = $HostName
            Message        = "No files were successfully exported"
        }
    }
    
    # Merge the exported files
    Write-RVToolsLog -Message "Merging $($exportedFiles.Count) exported files into $finalExportFile" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
    
    try {
        if (-not $DryRun) {
            $mergeResult = Merge-RVToolsExcelFiles -SourceFiles $exportedFiles -DestinationFile $finalExportFile
            
            if ($mergeResult) {
                Write-RVToolsLog -Message "Successfully merged files into $finalExportFile" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                
                # Clean up temporary files and directory
                try {
                    Remove-Item -Path $tempSubDirectory -Recurse -Force
                    Write-RVToolsLog -Message "Cleaned up temporary subdirectory: $tempSubDirectory" -Level 'DEBUG' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                }
                catch {
                    Write-RVToolsLog -Message "Warning: Could not clean up temporary subdirectory: $($_.Exception.Message)" -Level 'WARN' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                }
                
                return @{
                    Success        = $true
                    FinalFile      = $finalExportFile
                    Files          = $exportedFiles
                    TempDirectory  = $tempSubDirectory
                    SuccessfulTabs = $exportedFiles.Count
                    FailedTabs     = $totalTabs - $exportedFiles.Count
                    HostName       = $HostName
                    Message        = "Successfully exported $($exportedFiles.Count) of $totalTabs tabs"
                }
            }
            else {
                Write-RVToolsLog -Message "Failed to merge files into $finalExportFile" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                return @{
                    Success        = $false
                    Error          = "Failed to merge files into $finalExportFile"
                    Files          = $exportedFiles
                    TempDirectory  = $tempSubDirectory
                    SuccessfulTabs = $exportedFiles.Count
                    FailedTabs     = $totalTabs - $exportedFiles.Count
                    HostName       = $HostName
                    Message        = "Failed to merge $($exportedFiles.Count) exported tabs"
                }
            }
        }
        else {
            Write-RVToolsLog -Message "[DRY RUN] Would merge files into $finalExportFile" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
            return @{
                Success        = $true
                FinalFile      = $finalExportFile
                Files          = $exportedFiles
                TempDirectory  = $tempSubDirectory
                SuccessfulTabs = $exportedFiles.Count
                FailedTabs     = $totalTabs - $exportedFiles.Count
                HostName       = $HostName
                Message        = "[DRY RUN] Would export $($exportedFiles.Count) of $totalTabs tabs"
            }
        }
    }
    catch {
        Write-RVToolsLog -Message "Exception during merge: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        return @{
            Success        = $false
            Error          = "Exception during merge: $($_.Exception.Message)"
            Files          = $exportedFiles
            TempDirectory  = $tempSubDirectory
            SuccessfulTabs = $exportedFiles.Count
            FailedTabs     = $totalTabs - $exportedFiles.Count
            HostName       = $HostName
            Message        = "Exception during merge after exporting $($exportedFiles.Count) tabs"
        }
    }
}
