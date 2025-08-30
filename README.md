# RVTools Daily Dump Toolkit

A reliable, configuration-driven PowerShell toolkit for automating RVTools exports across multiple vCenter servers with secure credential management. **Now featuring a complete PowerShell module architecture with professional-grade validation, pipeline support, and enhanced maintainability.**

## 🚀 Version 2.0.0 - Complete PowerShell Module Architecture

### **Professional Module Implementation**

- **RVToolsModule v3.0.0**: Complete professional PowerShell module with 9 public functions and 4 private functions
- **Enhanced Scripts**: All 5 main scripts now leverage the module while maintaining backward compatibility
- **Code Reduction**: ~60% reduction in duplicate code through shared module functions
- **Professional Features**: Advanced validation, pipeline support, comprehensive help documentation

### **Backward Compatibility Maintained**

- **Same Interface**: All existing scripts work exactly as before - no retraining needed
- **Enhanced Functionality**: Scripts now benefit from professional-grade validation and error handling
- **Gradual Adoption**: Use traditional scripts or new module functions directly

## Features

- **🏗️ Professional Module Architecture**: Complete PowerShell module with enterprise-grade validation and pipeline support
- **🔄 Backward Compatibility**: All existing scripts preserved and enhanced to use the module
- **📊 Chunked Export Mode**: Handles large vCenter environments where standard export crashes due to memory issues
- **🔒 Secure Credential Management**: Uses PowerShell SecretManagement for unattended operation
- **🔐 Password Encryption**: Leverages RVTools' own DPAPI-based password encryption (no plaintext passwords)
- **⚙️ Configuration-Driven**: Separate configuration and host list files (templates provided)
- **🛠️ Reliable Operation**: DryRun capability, verbose logging, and error handling
- **✅ Validated RVTools Integration**: Uses Dell's recommended CLI approach with proper batch processing
- **📧 Email Summaries**: Optional email reports with run status and logs (SMTP or Microsoft Graph)
- **🚀 Easy Onboarding**: Automated dependency validation and vault initialization
- **🌐 Multi-vCenter Support**: Process multiple vCenter servers with individual or shared credentials

## 🚀 New Module Functions Available

With the new RVToolsModule architecture, you can now use professional PowerShell functions directly:

### **Core Module Functions**

```powershell
# Main export function with advanced features
Invoke-RVToolsExport -HostName 'vcenter01' -ConfigPath $config

# Pipeline support for bulk operations  
@('vcenter01', 'vcenter02', 'vcenter03') | Invoke-RVToolsExport

# Configuration management with template fallback
$config = Import-RVToolsConfiguration -ConfigPath $configPath

# Secure credential retrieval
$cred = Get-RVToolsCredentialFromVault -HostName 'vcenter01' -Username 'admin'

# Standardized logging across all operations
Write-RVToolsLog -Message "Export completed" -Level 'SUCCESS'

# Configuration validation and testing
Test-RVToolsConfiguration -ConfigPath $configPath

# Smart path resolution with validation
$resolvedPath = Resolve-RVToolsPath -Path $rvtoolsPath -ScriptRoot $PSScriptRoot

# Directory creation with proper error handling
New-RVToolsDirectory -Path $exportPath

# DPAPI password encryption
$encryptedPassword = Get-RVToolsEncryptedPassword -Credential $cred

# Secret name pattern generation
$secretName = Get-RVToolsSecretName -HostName $host -Username $user -Pattern $pattern
```

### **Traditional Script Usage (Still Works)**

All your existing automation continues to work exactly as before:

```powershell
# Your existing workflows are unchanged
.\Initialize-RVToolsDependencies.ps1
.\Set-RVToolsCredentials.ps1 -UpdateAll
.\RVToolsDump.ps1
```

## Quick Start

### 1. Initialize Dependencies

Run the initialization script to install required modules and set up SecretManagement:

```powershell
.\Initialize-RVToolsDependencies.ps1
```

This will:

- Install Microsoft.PowerShell.SecretManagement and SecretStore modules
- Install Microsoft Graph modules (if Microsoft Graph email is configured)
- Create and configure the RVToolsVault for unattended operation
- Validate RVTools installation
- Create required directories

### 2. Configure the Toolkit

Copy the template files to create your live configuration:

```powershell
Copy-Item "shared\Configuration-Template.psd1" "shared\Configuration.psd1"
Copy-Item "shared\HostList-Template.psd1" "shared\HostList.psd1"
```

Edit `shared\Configuration.psd1` to match your environment:

- Update `RVToolsPath` to your RVTools installation
- Configure email settings if desired

Edit `shared\HostList.psd1` with your vCenter servers:

```powershell
@{
    Hosts = @(
        # Simple format using default username from configuration
        'vcenter01.contoso.local'
        'vcenter02.contoso.local'
        
        # Hashtable format for specific usernames per host
        @{ Name = 'vcenter03.contoso.local'; Username = 'svc_rvtools@contoso.local' }
        @{ Name = 'vcenter-prod.contoso.local'; Username = 'prod_service@contoso.local' }
        
        # Large environments can use chunked export mode
        @{ Name = 'vcenter-large.contoso.local'; Username = 'svc_rvtools@contoso.local'; ExportMode = 'Chunked' }
    )
}
```

### Successful Execution Example

```text
2025-08-XX 18:XX:XX [INFO] Starting RVTools export for vcenter01.example.com
2025-08-XX 18:XX:XX [SUCCESS] Completed export for vcenter01.example.com  
2025-08-XX 18:XX:XX [INFO] Starting RVTools export for vcenter02.example.com
2025-08-XX 18:XX:XX [SUCCESS] Completed export for vcenter02.example.com
2025-08-XX 18:XX:XX [INFO] Run complete. Summary: SUCCESS - vcenter01.example.com; SUCCESS - vcenter02.example.com

Export files created:
- vcenter01.example.com-YYYYMMDD_HHMMSS.xlsx (XXX.X KB)
- vcenter02.example.com-YYYYMMDD_HHMMSS.xlsx (XXX.X KB)
```

### 3. Store Credentials

Use the credential management script to securely store credentials for all hosts:

```powershell
# Store credentials for all hosts in the host list
.\Set-RVToolsCredentials.ps1 -UpdateAll

# Or store credentials for a specific host
.\Set-RVToolsCredentials.ps1 -HostName "vcenter01.contoso.local" -Username "svc_rvtools"

# List stored credentials
.\Set-RVToolsCredentials.ps1 -ListCredentials
```

#### Microsoft Graph Email Setup

If using Microsoft Graph email, store the ClientSecret securely:

```powershell
# Store Microsoft Graph ClientSecret in the vault (recommended)
.\Set-MicrosoftGraphCredentials.ps1 -Store -ClientSecret 'your-actual-client-secret'

# List Microsoft Graph credentials (without showing the secret)
.\Set-MicrosoftGraphCredentials.ps1 -Show

# Update an existing ClientSecret
.\Set-MicrosoftGraphCredentials.ps1 -Update -ClientSecret 'new-client-secret'
```

### 4. Test the Setup

Run a dry-run to validate configuration and connectivity:

```powershell
.\RVToolsDump.ps1 -DryRun
```

Then run a real export:

```powershell
# Standard export (existing behavior)
.\RVToolsDump.ps1

# Chunked export for large environments with memory issues  
.\RVToolsDump.ps1 -ChunkedExport
```

## 🚀 Chunked Export Mode (New in v1.3.0)

For large vCenter environments where standard RVTools export crashes due to memory issues, use the new chunked export mode:

```powershell
.\RVToolsDump.ps1 -ChunkedExport
```

### How Chunked Export Works

1. **Individual Tab Exports**: Exports each of the 26 RVTools tabs separately (vInfo, vCPU, vMemory, vDisk, etc.)
2. **Memory Efficiency**: Each tab uses less memory than full export, reducing crash risk
3. **Fault Tolerance**: Continues even if some tabs fail due to crashes
4. **Smart Merging**: Uses Excel COM to combine successful tabs into single consolidated file
   - Automatically excludes duplicate vMetaData tabs (keeps only the first one)
   - Maintains all unique data while reducing file complexity
5. **Automatic Cleanup**: Removes all temporary tab files after merge completion

### When to Use Chunked Export

- **Large Environments**: 10,000+ VMs or complex infrastructure
- **Memory Issues**: Standard export crashes with memory errors
- **Partial Success Acceptable**: Better to get most data than no data
- **Troubleshooting**: Identify which specific tabs cause issues

### Example Output

```text
2025-08-XX 08:XX:XX [INFO] Starting chunked export for vcenter-large.domain.com
...tab exports...
2025-08-XX 09:XX:XX [INFO] Tab export summary - Successful: XX, Failed: 2
2025-08-XX 09:XX:XX [WARN] Failed tabs: vNIC (crash), vSwitch (crash)
2025-08-XX 09:XX:XX [INFO] Found XX successful tab exports out of XX attempted
2025-08-XX 10:XX:XX [SUCCESS] Successfully merged XX Excel files into final export
2025-08-XX 10:XX:XX [SUCCESS] Completed partial chunked export (XX/XX tabs)
```

### Per-Host Export Mode Configuration

You can configure export mode on a per-host basis in your `HostList.psd1` file, which is ideal for scheduled operations where only specific large environments need chunked export:

```powershell
@{
    Hosts = @(
        # Standard hosts use normal export mode by default
        'vcenter01.contoso.local'
        'vcenter02.contoso.local'
        
        # Large hosts can be configured for chunked export
        @{ Name = 'vcenter-large.contoso.local'; Username = 'svc_rvtools@contoso.local'; ExportMode = 'Chunked' }
        @{ Name = 'vcenter-huge.contoso.local'; Username = 'admin@vsphere.local'; ExportMode = 'Chunked' }
        
        # Mix normal and chunked hosts in the same configuration
        @{ Name = 'vcenter-prod.contoso.local'; Username = 'prod_service@contoso.local'; ExportMode = 'Normal' }
    )
}
```

**ExportMode Options:**

- `'Normal'` (default): Standard RVTools export for smaller environments
- `'Chunked'`: Individual tab export with merging for large environments

**Benefits of Per-Host Configuration:**

- **Scheduled Operations**: Set once in configuration rather than command-line parameters
- **Mixed Environments**: Handle both small and large vCenters in the same run
- **Maintenance-Free**: No need to remember which hosts need special handling

## 📧 Email Configuration

The toolkit supports two email methods for sending daily reports:

### Microsoft Graph Email (Recommended)

Modern email method using OAuth2 authentication with Microsoft 365:

```powershell
Email = @{
    Enabled   = $true
    Method    = 'MicrosoftGraph'
    From      = 'rvtools@contoso.com'
    To        = @('reports@contoso.com', 'team@contoso.com')
    
    # Azure AD App Registration details
    TenantId         = 'your-tenant-id-guid'
    ClientId         = 'your-client-id-guid'
    ClientSecretName = 'MicrosoftGraph-ClientSecret'  # Stored securely in vault
}
```

**Setup Requirements:**

1. **Azure AD App Registration**: Create an app registration with Mail.Send permissions
2. **Store ClientSecret securely**:

   ```powershell
   # Use the helper script to store the ClientSecret in the vault
   .\Set-MicrosoftGraphCredentials.ps1 -Store -ClientSecret 'your-actual-client-secret'
   ```

3. **Configuration**: Use `ClientSecretName` instead of plaintext `ClientSecret`

**Benefits:**

- OAuth2 authentication (more secure than SMTP credentials)
- **Secure credential storage** (no plaintext secrets in configuration files)
- Firewall-friendly (HTTPS only, no SMTP ports needed)
- Integrated with Microsoft 365 audit logging
- Free with existing M365 licensing

### Traditional SMTP Email

Classic SMTP method for non-Microsoft environments:

```powershell
Email = @{
    Enabled   = $true
    Method    = 'SMTP'  # Default for backward compatibility
    From      = 'rvtools@contoso.com'
    To        = @('reports@contoso.com')
    SmtpServer= 'smtp.contoso.com'
    Port      = 587
    UseSsl    = $true
}
```

## ✅ Validated RVTools Integration

This toolkit uses Dell's recommended RVTools CLI approach, based on their official `RVToolsBatchMultipleVCs.ps1` script:

- **Proper CLI Arguments**: Uses `-c ExportAll2xlsx` with separated `-d` (directory) and `-f` (filename) parameters
- **Process Management**: Implements `Start-Process` with `-NoNewWindow -Wait -PassThru` as recommended by Dell
- **Working Directory**: Changes to RVTools directory during execution for compatibility
- **Exit Code Handling**: Properly detects connection failures (exit code -1) and other errors
- **Path Handling**: Properly quotes paths containing spaces for reliable execution

### Export Results

The script generates individual Excel files for each vCenter server:

- `vcenter-server-YYYYMMDD_HHMMSS.xlsx` format
- Files stored in the configured export directory
- Typical file sizes: 200-500KB depending on environment size

## File Structure

```plaintext
RVToolsDailyDump/
├── RVToolsDump.ps1                       # Main export script (enhanced with module)
├── Set-RVToolsCredentials.ps1            # vCenter credential management (enhanced)
├── Set-MicrosoftGraphCredentials.ps1     # Microsoft Graph secret management (enhanced)
├── Initialize-RVToolsDependencies.ps1    # Setup and validation (enhanced)
├── RVToolsModule/                        # NEW: Professional PowerShell module
│   ├── RVToolsModule.psd1                # Module manifest
│   ├── RVToolsModule.psm1                # Module loader
│   ├── Public/                           # 9 exported functions
│   │   ├── Invoke-RVToolsExport.ps1      # Main export cmdlet with advanced features
│   │   ├── Import-RVToolsConfiguration.ps1 # Configuration loading with template fallback
│   │   ├── Get-RVToolsCredentialFromVault.ps1 # Secure credential retrieval
│   │   ├── Write-RVToolsLog.ps1          # Standardized logging
│   │   ├── Test-RVToolsConfiguration.ps1 # Configuration validation
│   │   ├── Resolve-RVToolsPath.ps1       # Smart path resolution
│   │   ├── New-RVToolsDirectory.ps1      # Directory creation with error handling
│   │   ├── Get-RVToolsEncryptedPassword.ps1 # DPAPI password encryption
│   │   └── Get-RVToolsSecretName.ps1     # Secret name pattern generation
│   ├── Private/                          # 4 internal helper functions
│   │   ├── Get-RVToolsConfigTemplate.ps1
│   │   ├── Get-RVToolsHostListTemplate.ps1
│   │   ├── Test-RVToolsRequiredModules.ps1
│   │   └── ConvertTo-RVToolsHostObject.ps1
│   └── Classes/                          # Custom validation classes
│       └── RVToolsValidation.ps1         # ValidateRVToolsPath, ValidateRVToolsConfig, etc.
├── shared/
│   ├── Configuration-Template.psd1       # Config template
│   ├── HostList-Template.psd1            # Host list template
│   ├── Configuration.psd1                # Live config (ignored by Git)
│   └── HostList.psd1                     # Live host list (ignored by Git)
├── test/                                 # Enhanced test suite
│   ├── Run-Tests.ps1                     # Main test runner
│   ├── Test-Configuration.ps1            # Configuration validation tests
│   ├── Test-Credentials.ps1              # Credential management tests
│   └── Test-RVToolsPasswordEncryption.ps1 # Password encryption tests
├── exports/                              # Export files (ignored by Git)
└── logs/                                 # Log files (ignored by Git)
```

## Configuration Options

### Authentication

- `Method`: 'SecretManagement' (recommended) or 'Prompt'
- `DefaultVault`: SecretManagement vault name
- `SecretNamePattern`: Pattern for secret names (default: '{HostName}-{Username}')
- `UsePasswordEncryption`: Use RVTools DPAPI password encryption (recommended: true)

### Logging

- `EnableDebug`: Enable verbose debug output
- `LogLevel`: 'DEBUG', 'INFO', 'WARN', 'ERROR'

## Advanced Usage

### Credential Management

#### vCenter Credentials

```powershell
# Update a specific credential (e.g., after password rotation)
.\Set-RVToolsCredentials.ps1 -HostName "vcenter01.contoso.local" -Username "svc_rvtools"

# Remove a stored credential (now supports username specification)
.\Set-RVToolsCredentials.ps1 -RemoveCredential -HostName "vcenter01.contoso.local" -Username "svc_rvtools"

# List all stored credentials (improved parsing for complex hostnames)
.\Set-RVToolsCredentials.ps1 -ListCredentials
```

#### Microsoft Graph Credentials

```powershell
# Store Microsoft Graph ClientSecret securely in vault
.\Set-MicrosoftGraphCredentials.ps1 -Store -ClientSecret 'your-actual-client-secret'

# Update an existing ClientSecret (e.g., after secret rotation)
.\Set-MicrosoftGraphCredentials.ps1 -Update -ClientSecret 'new-client-secret'

# Show current Microsoft Graph configuration (without revealing secret)
.\Set-MicrosoftGraphCredentials.ps1 -Show

# List all secrets in the vault
.\Set-MicrosoftGraphCredentials.ps1 -List

# Remove Microsoft Graph ClientSecret from vault
.\Set-MicrosoftGraphCredentials.ps1 -Remove
```

### Export Mode Selection

```powershell
# Standard export (recommended for smaller environments)
.\RVToolsDump.ps1

# Chunked export (for large environments with memory issues)
.\RVToolsDump.ps1 -ChunkedExport

# Test either mode without running RVTools
.\RVToolsDump.ps1 -DryRun
.\RVToolsDump.ps1 -ChunkedExport -DryRun
```

### Scheduling

Create a scheduled task to run daily:

```powershell
# Example: Create scheduled task (run as administrator)
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File 'C:\Path\To\RVToolsDump.ps1'"
$trigger = New-ScheduledTaskTrigger -Daily -At "06:00"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "RVTools Daily Export" -Action $action -Trigger $trigger -Settings $settings -User "DOMAIN\svc_rvtools"
```

## Security Considerations

- **Password Encryption**: Uses RVTools' DPAPI-based encryption (same user/computer only)
- **Secure Secret Storage**: Microsoft Graph ClientSecret stored encrypted in SecretManagement vault
- **No Plaintext Secrets**: Configuration files contain only secret names, not actual secrets
- **Least Privilege**: Use a dedicated service account with minimal vCenter permissions
- **Credential Storage**: All credentials are encrypted in SecretManagement vault
- **Network Security**: Ensure secure communication to vCenter
- **File Permissions**: Restrict access to the toolkit directory
- **Secret Rotation**: Use credential management scripts to update rotated passwords/secrets

## Troubleshooting

### RVTools Issues

**Problem**: RVTools opens GUI instead of running export

- **Solution**: Script now uses `-c ExportAll2xlsx` and proper Dell CLI approach

**Problem**: Export files not created or in wrong location  

- **Solution**: Script now uses quoted paths and proper `-d`/`-f` parameter separation

**Problem**: Connection failures

- **Solution**: Check service account permissions on vCenter and verify stored credentials

**Validation Steps**:

```powershell
# 1. Test with dry-run first
.\RVToolsDump.ps1 -DryRun

# 2. Check stored credentials
.\Set-RVToolsCredentials.ps1 -ListCredentials

# 3. Verify RVTools path in configuration
Test-Path "C:\Program Files (x86)\Dell\RVTools\RVTools.exe"
```

### SecretManagement Issues

```powershell
# Check vault status
Get-SecretVault

# Reset vault configuration
.\Initialize-RVToolsDependencies.ps1 -Force
```

### Debug Logging

Enable debug logging in configuration:

```powershell
Logging = @{
    EnableDebug = $true
    LogLevel = 'DEBUG'
}
```

## Recent Updates

### August 2025 v2.0.0 - Complete PowerShell Module Architecture

- **🏗️ Professional Module**: Complete RVToolsModule (v3.0.0) with 9 public functions and 4 private functions
- **🔄 Backward Compatibility**: All existing scripts preserved and enhanced to use the module
- **📊 Code Reduction**: ~60% reduction in duplicate code through shared module functions
- **✅ Professional Features**: Advanced validation, pipeline support, comprehensive help documentation
- **📚 Enhanced Documentation**: Organized documentation structure with phase progression summaries
- **🧹 Clean Codebase**: Development artifacts archived, production directory contains only active files
- **🎯 Benefits**: Enhanced reliability, consistent patterns, easier maintenance, same familiar interface

### August 2025 v1.4.2 - Unique Log Files Per Run

- **Logging Enhancement**: Log files now include timestamp for unique naming per execution
- **Email Improvement**: Email reports contain only logs from current run, not entire day
- **Format Change**: From `RVTools_RunLog_YYYYMMDD.txt` to `RVTools_RunLog_YYYYMMDD_HHMMSS.txt`
- **Cleaner Reports**: No more cumulative daily logs in email reports

### August 2025 v1.4.1 - Secure Microsoft Graph Secret Storage

- **Enhanced Security**: Microsoft Graph ClientSecret now stored encrypted in SecretManagement vault
- **New Helper Script**: `Set-MicrosoftGraphCredentials.ps1` for secure secret management
- **Configuration Change**: Use `ClientSecretName` instead of plaintext `ClientSecret`
- **No Plaintext Secrets**: Configuration files contain only secret references, not actual secrets
- **Bug Fix**: Resolved parameter binding issue with Microsoft Graph email function

### August 2025 v1.3.0 - Chunked Export & Enhanced Credential Management

- **New Feature**: Chunked export mode for large environments (`-ChunkedExport` parameter)
- **Memory Optimization**: Individual tab exports reduce memory usage and crash risk
- **Enhanced Reliability**: Fault-tolerant processing continues even if some tabs fail  
- **Improved Cleanup**: Automatic removal of all temporary files including stub files
- **Better Credential Management**: Username support for credential removal and improved parsing
- **Detailed Logging**: Tab-by-tab success/failure reporting with exit code interpretation

### August 2025 v1.2.0 - RVTools CLI Integration Fixes

- **Fixed RVTools CLI execution**: Now uses Dell's recommended approach from `RVToolsBatchMultipleVCs.ps1`
- **Resolved export file creation issues**: Proper path quoting and parameter structure
- **Enhanced process management**: Uses `Start-Process` with proper wait and exit code handling
- **Improved error detection**: Better handling of connection failures (exit code -1)
- **Validated multi-vCenter support**: Successfully tested with multiple production vCenter servers

### Core Improvements

- **HostList format**: Changed to hashtable structure for better PowerShell compatibility
- **Credential management**: Enhanced username validation and error handling  
- **Test framework**: Comprehensive test suite for configuration, credentials, and encryption
- **Documentation**: Updated with validated RVTools integration patterns

## Requirements

- PowerShell 7+ (recommended) or Windows PowerShell 5.1
- RVTools 4.0+ installed (validated with Dell RVTools CLI standards)
- **NEW**: RVToolsModule v3.0.0 (included in this toolkit)
- Microsoft.PowerShell.SecretManagement module
- Microsoft.PowerShell.SecretStore module  
- Microsoft Graph modules (if using Microsoft Graph email)
- Windows DPAPI (for RVTools password encryption)

## Module Usage Examples

### Advanced Pipeline Operations

```powershell
# Import the module directly for advanced usage
Import-Module .\RVToolsModule

# Process multiple hosts with pipeline support
@('vcenter01', 'vcenter02', 'vcenter03') | Invoke-RVToolsExport -ConfigPath $config

# Bulk credential management
$hosts | ForEach-Object { 
    Get-RVToolsCredentialFromVault -HostName $_ -Username 'admin' 
}

# Configuration validation across multiple environments
$configPaths | Test-RVToolsConfiguration
```

### Direct Function Usage

```powershell
# Use module functions directly in custom scripts
$config = Import-RVToolsConfiguration -ConfigPath $configPath -PreferTemplate:$false
$exportPath = Resolve-RVToolsPath -Path $config.ExportFolder -ScriptRoot $PSScriptRoot  
New-RVToolsDirectory -Path $exportPath

# Advanced logging with consistent formatting
Write-RVToolsLog -Message "Custom operation completed" -Level 'SUCCESS' -LogFile $logPath
```

## Migration from Previous Versions

### From v1.x to v2.0.0

**✅ No Breaking Changes**: All existing scripts continue to work exactly as before.

**Enhanced Features Available**:

- Better error handling and validation
- Consistent logging patterns
- Pipeline support for bulk operations
- Professional help documentation
- Advanced validation attributes

**Optional Enhancements**:

```powershell
# Continue using traditional approach (recommended for existing automation)
.\RVToolsDump.ps1 -ChunkedExport

# Or leverage new module functions for custom scenarios
Import-Module .\RVToolsModule
Invoke-RVToolsExport -HostName 'vcenter01' -ChunkedExport
```

## License

This toolkit is provided as-is for internal use. Customize as needed for your environment.
