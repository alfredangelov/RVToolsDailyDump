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

    .PARAMETER LogFile
        Path to log file for logging output.

    .PARAMETER ConfigLogLevel
        Log level for output filtering.

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
        [switch]$DryRun,
        
        [Parameter()]
        [string]$LogFile,
        
        [Parameter()]
        [string]$ConfigLogLevel = 'INFO'
    )
    
    function Test-RVToolsConnectivity {
        param([string]$HostName, [string]$LogFile, [string]$ConfigLogLevel)
        
        Write-RVToolsLog -Message "Testing connectivity to $HostName..." -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        
        # Test basic connectivity
        try {
            $testResult = Test-NetConnection -ComputerName $HostName -Port 443 -WarningAction SilentlyContinue
            if ($testResult.TcpTestSucceeded) {
                Write-RVToolsLog -Message "✅ HTTPS connectivity to $HostName successful" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
            } else {
                Write-RVToolsLog -Message "❌ HTTPS connectivity to $HostName failed" -Level 'WARN' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
            }
        } catch {
            Write-RVToolsLog -Message "❌ Connectivity test failed: $($_.Exception.Message)" -Level 'WARN' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        }
    }
    
    function Get-RVToolsLogContent {
        param([string]$RVToolsPath, [string]$LogFile, [string]$ConfigLogLevel)
        
        $rvToolsDir = Split-Path $RVToolsPath -Parent
        $possibleLogPaths = @(
            Join-Path $rvToolsDir "RVTools.log"
            Join-Path $rvToolsDir "logs\RVTools.log"
            Join-Path $rvToolsDir "RVTools_Error.log"
            Join-Path $env:TEMP "RVTools.log"
            Join-Path $env:USERPROFILE "RVTools.log"
        )
        
        foreach ($logPath in $possibleLogPaths) {
            if (Test-Path $logPath) {
                Write-RVToolsLog -Message "📝 Found RVTools log: $logPath" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                try {
                    $logContent = Get-Content $logPath -Tail 20 -ErrorAction SilentlyContinue
                    if ($logContent) {
                        Write-RVToolsLog -Message "📝 Recent RVTools log entries:" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                        foreach ($line in $logContent) {
                            if ($line.Trim()) {
                                Write-RVToolsLog -Message "    $line" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                            }
                        }
                    }
                } catch {
                    Write-RVToolsLog -Message "⚠️ Could not read RVTools log: $($_.Exception.Message)" -Level 'WARN' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                }
                break
            }
        }
    }
    
    function Test-ExportPrerequisites {
        param([string]$ExportDirectory, [string]$LogFile, [string]$ConfigLogLevel)
        
        # Check disk space
        try {
            $drive = Split-Path $ExportDirectory -Qualifier
            $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$drive'"
            $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            
            if ($freeSpaceGB -lt 1) {
                Write-RVToolsLog -Message "⚠️ Low disk space on $drive - only ${freeSpaceGB}GB available" -Level 'WARN' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
            } else {
                Write-RVToolsLog -Message "✅ Sufficient disk space: ${freeSpaceGB}GB available on $drive" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
            }
        } catch {
            Write-RVToolsLog -Message "⚠️ Could not check disk space: $($_.Exception.Message)" -Level 'WARN' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        }
        
        # Check export directory permissions
        try {
            $testFile = Join-Path $ExportDirectory "test_$(Get-Random).tmp"
            "test" | Out-File $testFile -Force
            Remove-Item $testFile -Force
            Write-RVToolsLog -Message "✅ Export directory is writable" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        } catch {
            Write-RVToolsLog -Message "❌ Export directory write test failed: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        }
    }
    
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
                Write-RVToolsLog -Message "Starting RVTools export for $HostName to $exportFile" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                
                # Run pre-export diagnostics
                Test-RVToolsConnectivity -HostName $HostName -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                Test-ExportPrerequisites -ExportDirectory $ExportDirectory -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                
                # Change to RVTools directory (as recommended by Dell)
                $originalLocation = Get-Location
                Set-Location (Split-Path $RVToolsPath -Parent)
                
                try {
                    # Log the command being executed (with password redacted)
                    $logArgs = $rvToolsArgs -replace $passwordArg, '<redacted>'
                    Write-RVToolsLog -Message "Executing: $RVToolsPath $($logArgs -join ' ')" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                    
                    # Create temporary files to capture output
                    $tempStdOut = [System.IO.Path]::GetTempFileName()
                    $tempStdErr = [System.IO.Path]::GetTempFileName()
                    
                    try {
                        # Use Start-Process with output capture
                        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                        $processInfo.FileName = $RVToolsPath
                        $processInfo.Arguments = ($rvToolsArgs -join ' ')
                        $processInfo.UseShellExecute = $false
                        $processInfo.RedirectStandardOutput = $true
                        $processInfo.RedirectStandardError = $true
                        $processInfo.CreateNoWindow = $true
                        
                        $process = New-Object System.Diagnostics.Process
                        $process.StartInfo = $processInfo
                        
                        # Capture output
                        $stdOutBuilder = New-Object System.Text.StringBuilder
                        $stdErrBuilder = New-Object System.Text.StringBuilder
                        
                        $stdOutEvent = Register-ObjectEvent -InputObject $process -EventName 'OutputDataReceived' -Action {
                            if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
                                $Event.MessageData.AppendLine($EventArgs.Data)
                            }
                        } -MessageData $stdOutBuilder
                        
                        $stdErrEvent = Register-ObjectEvent -InputObject $process -EventName 'ErrorDataReceived' -Action {
                            if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
                                $Event.MessageData.AppendLine($EventArgs.Data)
                            }
                        } -MessageData $stdErrBuilder
                        
                        $process.Start()
                        $process.BeginOutputReadLine()
                        $process.BeginErrorReadLine()
                        $process.WaitForExit()
                        
                        $code = $process.ExitCode
                        
                        # Clean up event handlers
                        Unregister-Event -SourceIdentifier $stdOutEvent.Name
                        Unregister-Event -SourceIdentifier $stdErrEvent.Name
                        
                        Write-RVToolsLog -Message "RVTools process completed with exit code: $code" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                        
                        # Log captured output
                        $stdOut = $stdOutBuilder.ToString().Trim()
                        $stdErr = $stdErrBuilder.ToString().Trim()
                        
                        if ($stdOut) {
                            Write-RVToolsLog -Message "📤 RVTools stdout output:" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                            foreach ($line in ($stdOut -split "`n")) {
                                if ($line.Trim()) {
                                    Write-RVToolsLog -Message "    $($line.Trim())" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                                }
                            }
                        }
                        
                        if ($stdErr) {
                            Write-RVToolsLog -Message "📤 RVTools stderr output:" -Level 'WARN' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                            foreach ($line in ($stdErr -split "`n")) {
                                if ($line.Trim()) {
                                    Write-RVToolsLog -Message "    $($line.Trim())" -Level 'WARN' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                                }
                            }
                        }
                        
                        # Check RVTools log files for additional information
                        Get-RVToolsLogContent -RVToolsPath $RVToolsPath -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                        
                    } finally {
                        # Clean up temp files
                        if (Test-Path $tempStdOut) { Remove-Item $tempStdOut -Force }
                        if (Test-Path $tempStdErr) { Remove-Item $tempStdErr -Force }
                    }
                    
                    if ($code -eq 0) {
                        # Verify that the export file was actually created
                        if (Test-Path -LiteralPath $exportFile) {
                            $fileInfo = Get-Item -LiteralPath $exportFile
                            Write-RVToolsLog -Message "Completed export for $HostName (file size: $($fileInfo.Length) bytes)" -Level 'SUCCESS' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                            return [pscustomobject]@{
                                HostName = $HostName
                                Success = $true
                                ExportFile = $exportFile
                                ExitCode = $code
                                Message = "SUCCESS"
                            }
                        } else {
                            Write-RVToolsLog -Message "RVTools reported success but export file was not created: $exportFile" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                            Write-RVToolsLog -Message "🔍 This usually indicates authentication failure, insufficient permissions, or network connectivity issues" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                            return [pscustomobject]@{
                                HostName = $HostName
                                Success = $false
                                ExportFile = $null
                                ExitCode = $code
                                Message = "EXPORT FILE NOT CREATED"
                            }
                        }
                    } elseif ($code -eq -1) {
                        Write-RVToolsLog -Message "RVTools connection failed for $HostName (exit code -1)" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                        return [pscustomobject]@{
                            HostName = $HostName
                            Success = $false
                            ExportFile = $null
                            ExitCode = $code
                            Message = "CONNECTION FAILED"
                        }
                    } else {
                        Write-RVToolsLog -Message "RVTools exit code $code for $HostName" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
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
                Write-RVToolsLog -Message "[Dry-Run] Would run: $RVToolsPath $($rvToolsArgs -join ' ')" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
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
        Write-RVToolsLog -Message "Exception while exporting ${HostName}: $($err.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        return [pscustomobject]@{
            HostName = $HostName
            Success = $false
            ExportFile = $null
            ExitCode = $null
            Message = "ERROR - $($err.Exception.Message)"
        }
    }
}
