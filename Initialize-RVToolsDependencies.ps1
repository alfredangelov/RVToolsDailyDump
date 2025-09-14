<#
.SYNOPSIS
    Initialize dependencies and vaults for RVTools Daily Dump toolkit.

.DESCRIPTION
    This script validates and installs required PowerShell modules, initializes
    SecretManagement vaults, and validates the environment for RVTools operations.

.PARAMETER ConfigPath
    Path to the configuration file. Defaults to shared/Configuration.psd1.

.PARAMETER Force
    Force reinstallation of modules and recreation of vaults.

.PARAMETER SkipModuleInstall
    Skip PowerShell module installation (assumes modules are already installed).

.EXAMPLE
    .\Initialize-RVToolsDependencies.ps1

.EXAMPLE
    .\Initialize-RVToolsDependencies.ps1 -Force
#>

[CmdletBinding()]
param(
    [Parameter()] [string] $ConfigPath = (Join-Path $PSScriptRoot 'shared/Configuration.psd1'),
    [Parameter()] [switch] $Force,
    [Parameter()] [switch] $SkipModuleInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import RVTools module for common functions
try {
    Import-Module (Join-Path $PSScriptRoot 'RVToolsModule') -Force -ErrorAction Stop
    Write-Verbose "RVToolsModule loaded successfully"
}
catch {
    Write-Warning "RVToolsModule not available. Using local functions."
    
    # Fallback function if module not available
    function Write-Log {
        param(
            [Parameter(Mandatory)] [string] $Message,
            [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')] [string] $Level = 'INFO'
        )
        $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        Write-Host $line
    }
}

# Use module function or fallback
if (Get-Command Write-RVToolsLog -ErrorAction SilentlyContinue) {
    function Write-Log {
        param(
            [Parameter(Mandatory)] [string] $Message,
            [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')] [string] $Level = 'INFO'
        )
        Write-RVToolsLog -Message $Message -Level $Level
    }
}

function Test-ModuleAvailable {
    param([Parameter(Mandatory)] [string] $ModuleName)
    $module = Get-Module -Name $ModuleName -ListAvailable
    return $null -ne $module
}

function Install-RequiredModule {
    param(
        [Parameter(Mandatory)] [string] $ModuleName,
        [Parameter()] [string] $MinimumVersion
    )
    
    if ($SkipModuleInstall) {
        Write-Log -Level 'INFO' -Message "Skipping module installation: $ModuleName"
        return
    }
    
    Write-Log -Level 'INFO' -Message "Checking module: $ModuleName"
    
    if (Test-ModuleAvailable -ModuleName $ModuleName) {
        if ($Force) {
            Write-Log -Level 'INFO' -Message "Updating module: $ModuleName"
            Update-Module -Name $ModuleName -Force
        }
        else {
            Write-Log -Level 'SUCCESS' -Message "Module already available: $ModuleName"
            return
        }
    }
    
    try {
        Write-Log -Level 'INFO' -Message "Installing module: $ModuleName"
        $params = @{
            Name  = $ModuleName
            Force = $Force
            Scope = 'CurrentUser'
        }
        if ($MinimumVersion) {
            $params.MinimumVersion = $MinimumVersion
        }
        Install-Module @params
        Write-Log -Level 'SUCCESS' -Message "Successfully installed: $ModuleName"
    }
    catch {
        Write-Log -Level 'ERROR' -Message "Failed to install $ModuleName : $($_.Exception.Message)"
        throw
    }
}

function Initialize-SecretVault {
    param(
        [Parameter(Mandatory)] [string] $VaultName,
        [Parameter()] [string] $VaultType = 'Microsoft.PowerShell.SecretStore'
    )
    
    Write-Log -Level 'INFO' -Message "Initializing vault: $VaultName"
    
    # Check if vault already exists
    $existingVault = Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue
    if ($existingVault -and -not $Force) {
        Write-Log -Level 'SUCCESS' -Message "Vault already exists: $VaultName"
        return
    }
    
    if ($existingVault -and $Force) {
        Write-Log -Level 'INFO' -Message "Removing existing vault: $VaultName"
        Unregister-SecretVault -Name $VaultName
    }
    
    try {
        # Register the vault
        Register-SecretVault -Name $VaultName -ModuleName $VaultType -DefaultVault:$true
        Write-Log -Level 'SUCCESS' -Message "Successfully created vault: $VaultName"
        
        # Configure SecretStore for unattended operation
        if ($VaultType -eq 'Microsoft.PowerShell.SecretStore') {
            Set-SecretStoreConfiguration -Scope CurrentUser -Authentication None -Interaction None -Confirm:$false
            Write-Log -Level 'SUCCESS' -Message "Configured SecretStore for unattended operation"
        }
    }
    catch {
        Write-Log -Level 'ERROR' -Message "Failed to create vault $VaultName : $($_.Exception.Message)"
        throw
    }
}

function Test-RVToolsPath {
    param([Parameter(Mandatory)] [string] $RVToolsPath)
    
    Write-Log -Level 'INFO' -Message "Validating RVTools path: $RVToolsPath"
    
    if (Test-Path -LiteralPath $RVToolsPath) {
        Write-Log -Level 'SUCCESS' -Message "RVTools executable found"
        return $true
    }
    else {
        Write-Log -Level 'WARN' -Message "RVTools executable not found at: $RVToolsPath"
        
        # Check if winget is available and offer to install RVTools
        Write-Log -Level 'INFO' -Message "Checking if winget is available for automatic installation..."
        
        try {
            $wingetVersion = & winget --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Log -Level 'SUCCESS' -Message "winget found (version: $wingetVersion)"
                Write-Log -Level 'INFO' -Message "Attempting to install RVTools via winget..."
                
                $installResult = & winget install rvtools --accept-package-agreements --accept-source-agreements 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Log -Level 'SUCCESS' -Message "RVTools installation completed successfully"
                    Write-Log -Level 'INFO' -Message "Installation output: $($installResult -join '; ')"
                    
                    # Check if RVTools is now available at the expected path
                    if (Test-Path -LiteralPath $RVToolsPath) {
                        Write-Log -Level 'SUCCESS' -Message "RVTools executable now found at: $RVToolsPath"
                        
                        # Apply RVTools log4net configuration fix to prevent hanging
                        Write-Log -Level 'INFO' -Message "Applying RVTools log4net configuration fix..."
                        try {
                            $fixScriptPath = Join-Path $PSScriptRoot 'utilities\Fix-RVToolsLog4NetConfig.ps1'
                            if (Test-Path $fixScriptPath) {
                                & $fixScriptPath
                                Write-Log -Level 'SUCCESS' -Message "RVTools log4net configuration fix applied successfully"
                            }
                            else {
                                Write-Log -Level 'WARN' -Message "Fix script not found at: $fixScriptPath"
                            }
                        }
                        catch {
                            Write-Log -Level 'WARN' -Message "Failed to apply RVTools log4net fix: $($_.Exception.Message)"
                            Write-Log -Level 'INFO' -Message "You may need to run utilities\Fix-RVToolsLog4NetConfig.ps1 manually"
                        }
                        
                        return $true
                    }
                    else {
                        Write-Log -Level 'WARN' -Message "RVTools was installed but not found at expected path: $RVToolsPath"
                        Write-Log -Level 'INFO' -Message "You may need to update the RVToolsPath in your configuration file"
                        return $false
                    }
                }
                else {
                    Write-Log -Level 'ERROR' -Message "Failed to install RVTools via winget. Exit code: $LASTEXITCODE"
                    Write-Log -Level 'INFO' -Message "Error output: $($installResult -join '; ')"
                    Write-Log -Level 'INFO' -Message "Please install RVTools manually or update the RVToolsPath in configuration"
                    return $false
                }
            }
            else {
                Write-Log -Level 'WARN' -Message "winget is not available or not working properly"
                Write-Log -Level 'INFO' -Message "Please install RVTools manually from https://www.robware.net/rvtools/ or update the RVToolsPath in configuration"
                return $false
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message "Error checking winget availability: $($_.Exception.Message)"
            Write-Log -Level 'INFO' -Message "Please install RVTools manually from https://www.robware.net/rvtools/ or update the RVToolsPath in configuration"
            return $false
        }
    }
}

function Test-MicrosoftGraphModules {
    $authModule = Test-ModuleAvailable -ModuleName 'Microsoft.Graph.Authentication'
    $usersActionsModule = Test-ModuleAvailable -ModuleName 'Microsoft.Graph.Users.Actions'
    
    if ($authModule -and $usersActionsModule) {
        Write-Log -Level 'SUCCESS' -Message "Microsoft Graph modules available (Authentication + Users.Actions)"
        return $true
    }
    else {
        $missing = @()
        if (-not $authModule) { $missing += 'Microsoft.Graph.Authentication' }
        if (-not $usersActionsModule) { $missing += 'Microsoft.Graph.Users.Actions' }
        Write-Log -Level 'INFO' -Message "Microsoft Graph modules missing: $($missing -join ', ') (required for Microsoft Graph email)"
        return $false
    }
}

# Main execution
Write-Log -Level 'INFO' -Message "Starting RVTools dependency initialization..."

# Load configuration
if (Get-Command Import-RVToolsConfiguration -ErrorAction SilentlyContinue) {
    # Use module function
    $configResult = Import-RVToolsConfiguration -ConfigPath $ConfigPath -ScriptRoot $PSScriptRoot
    $cfg = $configResult.Configuration
}
else {
    # Fallback method
    $cfgFile = if (Test-Path $ConfigPath) { 
        $ConfigPath 
    }
    elseif (Test-Path (Join-Path $PSScriptRoot 'shared/Configuration-Template.psd1')) {
        Write-Log -Level 'WARN' -Message "Using template configuration for validation"
        (Join-Path $PSScriptRoot 'shared/Configuration-Template.psd1')
    }
    else {
        Write-Log -Level 'ERROR' -Message "Configuration file not found at: $ConfigPath"
        exit 1
    }
    
    $cfg = Import-PowerShellDataFile -Path $cfgFile
}

# Required modules
$requiredModules = @(
    @{ Name = 'Microsoft.PowerShell.SecretManagement'; MinimumVersion = '1.1.0' }
    @{ Name = 'Microsoft.PowerShell.SecretStore'; MinimumVersion = '1.0.0' }
    @{ Name = 'ImportExcel'; MinimumVersion = '7.1.0' }  # Required for chunked export Excel merging
)

# Microsoft Graph modules for email functionality
if ($cfg.Email?.Enabled -and $cfg.Email?.Method -eq 'MicrosoftGraph') {
    $requiredModules += @{ Name = 'Microsoft.Graph.Authentication'; MinimumVersion = '1.19.0' }
    $requiredModules += @{ Name = 'Microsoft.Graph.Users.Actions'; MinimumVersion = '1.19.0' }
}

# Install required modules
foreach ($module in $requiredModules) {
    Install-RequiredModule -ModuleName $module.Name -MinimumVersion $module.MinimumVersion
}

# Import SecretManagement modules
Import-Module Microsoft.PowerShell.SecretManagement -Force
Import-Module Microsoft.PowerShell.SecretStore -Force

# Initialize vault
$vaultName = $cfg.Auth?.DefaultVault ?? 'RVToolsVault'
Initialize-SecretVault -VaultName $vaultName

# Validate RVTools installation
$rvtoolsValid = Test-RVToolsPath -RVToolsPath $cfg.RVToolsPath

# Test Microsoft Graph modules if needed
$microsoftGraphValid = $false
if ($cfg.Email?.Enabled -and $cfg.Email?.Method -eq 'MicrosoftGraph') {
    $microsoftGraphValid = Test-MicrosoftGraphModules
}

# Create directories
$exportsRoot = Join-Path $PSScriptRoot ($cfg.ExportFolder ?? 'exports')
$logsRoot = Join-Path $PSScriptRoot ($cfg.LogsFolder ?? 'logs')

foreach ($dir in @($exportsRoot, $logsRoot)) {
    if (Get-Command New-RVToolsDirectory -ErrorAction SilentlyContinue) {
        New-RVToolsDirectory -Path $dir | Out-Null
    }
    else {
        # Fallback method
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            Write-Log -Level 'SUCCESS' -Message "Created directory: $dir"
        }
    }
}

# Summary
Write-Log -Level 'INFO' -Message "=== Initialization Summary ==="
Write-Log -Level 'INFO' -Message "SecretManagement modules: Installed"
Write-Log -Level 'INFO' -Message "ImportExcel module: Installed (for chunked export merging)"
Write-Log -Level 'INFO' -Message "Vault '$vaultName': Initialized"
Write-Log -Level 'INFO' -Message "RVTools executable: $(if ($rvtoolsValid) { 'Found' } else { 'NOT FOUND' })"

if ($cfg.Email?.Enabled -and $cfg.Email?.Method -eq 'MicrosoftGraph') {
    Write-Log -Level 'INFO' -Message "Microsoft Graph modules: $(if ($microsoftGraphValid) { 'Available' } else { 'NOT FOUND' })"
}
Write-Log -Level 'INFO' -Message "Export directory: $exportsRoot"
Write-Log -Level 'INFO' -Message "Logs directory: $logsRoot"

if (-not $rvtoolsValid) {
    Write-Log -Level 'WARN' -Message "Please install RVTools and update the configuration before running exports"
}

if ($cfg.Email?.Enabled -and $cfg.Email?.Method -eq 'MicrosoftGraph' -and -not $microsoftGraphValid) {
    Write-Log -Level 'WARN' -Message "Microsoft Graph modules required for email functionality. Run with -Force to install them."
}

Write-Log -Level 'INFO' -Message "Next steps:"
Write-Log -Level 'INFO' -Message "1. Copy shared/Configuration-Template.psd1 to shared/Configuration.psd1"
Write-Log -Level 'INFO' -Message "2. Copy shared/HostList-Template.psd1 to shared/HostList.psd1"
Write-Log -Level 'INFO' -Message "3. Run Set-RVToolsCredentials.ps1 to store host credentials"
Write-Log -Level 'INFO' -Message "4. Test with RVToolsDump.ps1 -DryRun"

Write-Log -Level 'SUCCESS' -Message "Dependency initialization complete!"
