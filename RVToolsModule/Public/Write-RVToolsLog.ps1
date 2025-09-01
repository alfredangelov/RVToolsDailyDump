function Write-RVToolsLog {
    <#
    .SYNOPSIS
        Writes log messages with timestamp and level formatting for RVTools operations.

    .DESCRIPTION
        This function provides centralized logging for all RVTools module operations.
        It supports different log levels and can optionally write to a log file.

    .PARAMETER Message
        The message to log.

    .PARAMETER Level
        The log level. Valid values are 'INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG'.

    .PARAMETER LogFile
        Optional path to a log file. If specified, messages will be written to both console and file.

    .PARAMETER ConfigLogLevel
        The minimum log level to display based on configuration. Messages below this level will be filtered.

    .EXAMPLE
        Write-RVToolsLog -Message "Starting RVTools export" -Level 'INFO'

    .EXAMPLE
        Write-RVToolsLog -Message "Export completed successfully" -Level 'SUCCESS' -LogFile "C:\logs\rvtools.log"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO',
        
        [Parameter()]
        [string]$LogFile,
        
        [Parameter()]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$ConfigLogLevel = 'INFO'
    )
    
    # Check if we should log this level
    $logLevels = @('DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS')
    $currentIndex = $logLevels.IndexOf($ConfigLogLevel)
    $messageIndex = $logLevels.IndexOf($Level)
    
    if ($messageIndex -ge $currentIndex -or $Level -eq 'SUCCESS') {
        $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        
        if ($LogFile) {
            $line | Tee-Object -FilePath $LogFile -Append | Out-Host
        } else {
            Write-Host $line
        }
    }
}
