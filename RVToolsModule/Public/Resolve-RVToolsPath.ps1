function Resolve-RVToolsPath {
    <#
    .SYNOPSIS
        Resolves absolute or relative paths for RVTools operations.

    .DESCRIPTION
        This function resolves paths, converting relative paths to absolute paths
        based on a script root directory.

    .PARAMETER Path
        The path to resolve.

    .PARAMETER ScriptRoot
        The root directory for resolving relative paths.

    .EXAMPLE
        Resolve-RVToolsPath -Path "exports" -ScriptRoot "C:\RVTools"

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [string]$ScriptRoot = $PWD.Path
    )
    
    if ([string]::IsNullOrWhiteSpace($Path)) { 
        return $null 
    }
    
    try { 
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path 
    } catch { 
        return (Join-Path $ScriptRoot $Path) 
    }
}
