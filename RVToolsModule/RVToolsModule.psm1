#Requires -Version 5.1

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName

# Module variables
$script:ModuleRoot = $PSScriptRoot
$script:ModuleVersion = (Import-PowerShellDataFile -Path "$PSScriptRoot\RVToolsModule.psd1").ModuleVersion

# Set strict mode for the module
Set-StrictMode -Version Latest
