function New-RVToolsDirectory {
    <#
    .SYNOPSIS
        Creates directories for RVTools operations if they don't exist.

    .DESCRIPTION
        This function ensures that required directories exist for RVTools exports,
        logs, and other operations.

    .PARAMETER Path
        The directory path to create.

    .EXAMPLE
        New-RVToolsDirectory -Path "C:\RVTools\exports"

    .OUTPUTS
        System.IO.DirectoryInfo
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-RVToolsLog -Message "Creating directory: $Path" -Level 'DEBUG'
        $directory = New-Item -ItemType Directory -Force -Path $Path
        Write-RVToolsLog -Message "Created directory: $Path" -Level 'INFO'
        return $directory
    } else {
        Write-RVToolsLog -Message "Directory already exists: $Path" -Level 'DEBUG'
        return Get-Item -LiteralPath $Path
    }
}
