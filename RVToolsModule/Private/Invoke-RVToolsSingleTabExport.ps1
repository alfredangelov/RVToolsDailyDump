function Invoke-RVToolsSingleTabExport {
    <#
    .SYNOPSIS
        Exports a single RVTools tab to Excel format.

    .DESCRIPTION
        This function performs a targeted export of a specific RVTools tab, providing
        fast, lightweight data collection for testing or focused analysis.

    .PARAMETER HostName
        The vCenter hostname to connect to.

    .PARAMETER Credential
        PSCredential object containing authentication information.

    .PARAMETER RVToolsPath
        Full path to the RVTools.exe executable.

    .PARAMETER ExportDirectory
        Directory where the export file will be saved.

    .PARAMETER TabName
        Name of the specific tab to export (e.g., 'vLicense', 'vInfo').

    .PARAMETER BaseFileName
        Base filename for the export (without extension).

    .PARAMETER UsePasswordEncryption
        Whether to use RVTools password encryption.

    .PARAMETER ExtraArgs
        Additional arguments to pass to RVTools.

    .PARAMETER DryRun
        Skip actual RVTools execution for testing.

    .EXAMPLE
        Invoke-RVToolsSingleTabExport -HostName "vcenter01.local" -Credential $cred -TabName "vLicense"

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
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
        [string]$TabName,
        
        [Parameter(Mandatory)]
        [string]$BaseFileName,
        
        [Parameter()]
        [switch]$UsePasswordEncryption,
        
        [Parameter()]
        [string[]]$ExtraArgs = @(),
        
        [Parameter()]
        [switch]$DryRun
    )
    
    # Get tab definitions to find the correct command
    $tabDefinitions = Get-RVToolsTabDefinitions
    $tabDef = $tabDefinitions | Where-Object { $_.FileName -eq $TabName }
    
    if (-not $tabDef) {
        $availableTabs = ($tabDefinitions | ForEach-Object { $_.FileName }) -join "', '"
        throw "Invalid tab name '$TabName'. Available tabs: '$availableTabs'"
    }
    
    # Create filename with tab name: hostname-timestamp-tabname.xlsx
    $exportFile = Join-Path $ExportDirectory "$BaseFileName-$TabName.xlsx"
    
    Write-RVToolsLog -Message "Starting single-tab export ($TabName) for $HostName to $exportFile" -Level 'INFO'
    
    if ($DryRun) {
        Write-RVToolsLog -Message "[Dry-Run] Would export $TabName tab for $HostName using command: $($tabDef.Command)" -Level 'INFO'
        return [pscustomobject]@{
            HostName = $HostName
            Success = $true
            ExportFile = $exportFile
            ExitCode = 0
            Message = "[Dry-Run] Single-tab export simulated for $TabName"
            TabName = $TabName
        }
    }
    
    # Prepare password argument
    $passwordArg = if ($Credential) {
        if ($UsePasswordEncryption) {
            Get-RVToolsEncryptedPassword -Credential $Credential
        } else {
            $Credential.GetNetworkCredential().Password
        }
    } else {
        ""
    }
    
    $logPasswordArg = if ($Credential) {
        if ($UsePasswordEncryption) { '<encrypted>' } else { '<redacted>' }
    } else {
        '<none>'
    }
    
    # Build RVTools arguments for single tab export
    $rvToolsArgs = if ($Credential) {
        @('-c', $tabDef.Command, '-s', $HostName, '-u', $Credential.UserName, '-p', $passwordArg, '-d', "`"$ExportDirectory`"", '-f', "$BaseFileName-$TabName") + $ExtraArgs
    } else {
        # Use Windows credentials - extract just the username part
        $simUser = if ($env:USERNAME.Contains('@')) { 
            $env:USERNAME.Split('@')[0] 
        } else { 
            $env:USERNAME 
        }
        @('-c', $tabDef.Command, '-s', $HostName, '-u', $simUser, '-p', $passwordArg, '-d', "`"$ExportDirectory`"", '-f', "$BaseFileName-$TabName") + $ExtraArgs
    }
    
    Write-RVToolsLog -Message "RVTools arguments: $($rvToolsArgs -replace $passwordArg, $logPasswordArg)" -Level 'DEBUG'
    
    try {
        if (-not $DryRun) {
            Write-RVToolsLog -Message "Starting single-tab export ($TabName) for $HostName" -Level 'INFO'
            
            # Change to RVTools directory (as recommended by Dell)
            $originalLocation = Get-Location
            Set-Location (Split-Path $RVToolsPath -Parent)
            
            try {
                # Use Start-Process as recommended by Dell's official script
                $process = Start-Process -FilePath $RVToolsPath -ArgumentList $rvToolsArgs -NoNewWindow -Wait -PassThru
                $code = $process.ExitCode
                
                if ($code -eq 0) {
                    Write-RVToolsLog -Message "Completed single-tab export ($TabName) for $HostName" -Level 'SUCCESS'
                    return [pscustomobject]@{
                        HostName = $HostName
                        Success = $true
                        ExportFile = $exportFile
                        ExitCode = $code
                        Message = "Single-tab export ($TabName) completed successfully"
                        TabName = $TabName
                    }
                } else {
                    Write-RVToolsLog -Message "Single-tab export ($TabName) failed for $HostName with exit code $code" -Level 'ERROR'
                    return [pscustomobject]@{
                        HostName = $HostName
                        Success = $false
                        ExportFile = $null
                        ExitCode = $code
                        Message = "Single-tab export ($TabName) failed with exit code $code"
                        TabName = $TabName
                    }
                }
            } finally {
                Set-Location $originalLocation
            }
        }
    } catch {
        Write-RVToolsLog -Message "Exception during single-tab export ($TabName) for $HostName`: $($_.Exception.Message)" -Level 'ERROR'
        return [pscustomobject]@{
            HostName = $HostName
            Success = $false
            ExportFile = $null
            ExitCode = -1
            Message = "Exception during single-tab export ($TabName): $($_.Exception.Message)"
            TabName = $TabName
        }
    }
}
