# RVTools Daily Dump Toolkit

A reliable, configuration-driven PowerShell toolkit for automating RVTools exports across multiple vCenter servers with secure credential management. **Now featuring TestMode for rapid development and comprehensive chunked export testing.**

## 🚀 Version 3.3.0 - TestMode & Development Efficiency Enhancement

### **Major New Features: TestMode & Enhanced Testing**

- **TestMode Parameter**: Fast development testing with only 3 tabs (vInfo, vHost, vDatastore) instead of all 26
- **Chunked Export Testing**: Comprehensive test framework for chunked export functionality validation
- **Version Management Cleanup**: Centralized version tracking to README.md and CHANGELOG.md only
- **Automatic Log4Net Fix**: Self-healing deployment that prevents RVTools hanging issues
- **Performance Benefits**: Single-tab exports are 350x smaller (9-10KB vs 350KB+)
- **License Auditing**: Use `vLicense` exports for efficient license tracking
- **Smart Integration**: Seamlessly integrated with existing Normal/Chunked export modes

### **How Single-Tab Exports Work**

Simply specify any valid RVTools tab name as the `ExportMode`:

```powershell
# HostList.psd1 configuration examples
@{
    Hosts = @(
        # Standard exports for general use
        @{ Name = 'vcenter01.contoso.local'; Username = 'admin'; ExportMode = 'Normal' }
        
        # Single-tab exports for specific purposes
        @{ Name = 'vcenter02.contoso.local'; Username = 'admin'; ExportMode = 'vLicense' }    # License auditing
        @{ Name = 'vcenter03.contoso.local'; Username = 'admin'; ExportMode = 'vInfo' }      # Basic VM info
        @{ Name = 'vcenter04.contoso.local'; Username = 'admin'; ExportMode = 'vHost' }      # Host information
        
        # Chunked exports for large environments
        @{ Name = 'vcenter-large.contoso.local'; Username = 'admin'; ExportMode = 'Chunked' }
    )
}
```

**Supported Tab Names**: `vInfo`, `vCPU`, `vMemory`, `vDisk`, `vPartition`, `vNetwork`, `vUSB`, `vCD`, `vSnapshot`, `vTools`, `vSource`, `vRP`, `vCluster`, `vHost`, `vHBA`, `vNIC`, `vSwitch`, `vPort`, `dvSwitch`, `dvPort`, `vSC_VMK`, `vDatastore`, `vMultiPath`, `vLicense`, `vFileInfo`, `vHealth`

### **Quick Start with Single-Tab Exports**

```powershell
# Standard export (existing behavior)
.\RVToolsDump.ps1

# All exports configured per host in HostList.psd1
.\RVToolsDump.ps1

# Test single-tab functionality
.\RVToolsDump.ps1 -DryRun
```

### **Use Cases for Single-Tab Exports**

- **🔍 Quick Connectivity Testing**: Use `vInfo` for fast connection validation
- **📊 License Auditing**: Use `vLicense` for lightweight license tracking  
- **🖥️ Host Monitoring**: Use `vHost` for infrastructure monitoring
- **💾 Storage Analysis**: Use `vDatastore` for storage-specific reports
- **⚡ Performance Testing**: Minimal data transfer for network-constrained environments

## Utilities

The `utilities/` folder contains maintenance and troubleshooting scripts for the RVTools environment.

### Fix-RVToolsLog4NetConfig.ps1

**Purpose:** Fixes a common log4net configuration issue in RVTools that prevents command-line operation.

**When to use:**

- After installing or updating RVTools
- When encountering errors like: "Failed to find configuration section 'log4net' in the application's .config file"
- When RVTools command-line operations fail with configuration-related errors

**Usage:**

```powershell
# Run PowerShell as Administrator, then:
cd utilities
.\Fix-RVToolsLog4NetConfig.ps1
```

This utility was created to resolve a configuration mismatch in RVTools where the main config file declares a log4net section but doesn't include the actual configuration, causing CLI operations to fail.

## Features

- **🚀 Single-Tab Export Capability**: Export specific RVTools tabs for targeted data collection and lightweight testing
- **🏗️ Professional Module Architecture**: Complete PowerShell module with enterprise-grade validation and pipeline support
- **🔄 Refactored Codebase**: Main scripts now leverage module functions, eliminating code duplication
- **📊 Chunked Export Mode**: Handles large vCenter environments where standard export crashes due to memory issues
- **🔒 Secure Credential Management**: Uses PowerShell SecretManagement for unattended operation
- **🔐 Password Encryption**: Leverages RVTools' own DPAPI-based password encryption (no plaintext passwords)
- **⚙️ Configuration-Driven**: Separate configuration and host list files (templates provided)
- **🛠️ Reliable Operation**: DryRun capability, verbose logging, and error handling
- **✅ Validated RVTools Integration**: Uses Dell's recommended CLI approach with proper batch processing
- **📧 Email Summaries**: Optional email reports with run status and logs (SMTP or Microsoft Graph)
- **🚀 Easy Onboarding**: Automated dependency validation and vault initialization
- **🌐 Multi-vCenter Support**: Process multiple vCenter servers with individual or shared credentials

## 🚀 Module Functions Now Used Throughout

With the completed refactoring, the main scripts now fully leverage these professional PowerShell functions:

### **Core Module Functions**

```powershell
# Main export function with advanced features (now used by RVToolsDump.ps1)
Invoke-RVToolsExport -HostName 'vcenter01' -ConfigPath $config

# Single-tab exports for specific purposes
Invoke-RVToolsExport -HostName 'vcenter01' -ExportMode 'vLicense'

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
- Install Microsoft.Graph.Authentication and Microsoft.Graph.Users.Actions modules (if Microsoft Graph email is configured)
- **Automatically install RVTools via winget** (if not present and winget is available)
- **Automatically apply log4net configuration fix** to prevent RVTools hanging issues
- Create and configure the RVToolsVault for unattended operation
- Validate RVTools installation and path configuration
- Create required directories (export/, log/)
- Provide detailed setup validation and diagnostics

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
        
        # Single-tab exports for specific purposes
        @{ Name = 'vcenter-license.contoso.local'; Username = 'svc_rvtools@contoso.local'; ExportMode = 'vLicense' }
    )
}
```

### Successful Execution Example

```text
2025-08-XX 18:XX:XX [INFO] Starting RVTools export for vcenter01.example.com
2025-08-XX 18:XX:XX [SUCCESS] Completed export for vcenter01.example.com  
2025-08-XX 18:XX:XX [INFO] Starting single-tab export (vLicense) for vcenter02.example.com
2025-08-XX 18:XX:XX [SUCCESS] Single-tab export (vLicense) completed successfully
2025-08-XX 18:XX:XX [INFO] Run complete. Summary: SUCCESS - vcenter01.example.com; SUCCESS - vcenter02.example.com

Export files created:
- vcenter01.example.com-YYYYMMDD_HHMMSS.xlsx (XXX.X KB)
- vcenter02.example.com-YYYYMMDD_HHMMSS-vLicense.xlsx (9.X KB)
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

**Test Email Functionality** (if configured):

```powershell
# Test Microsoft Graph email without running exports
.\test\Test-RVToolsEmail.ps1

# Test with custom recipient
.\test\Test-RVToolsEmail.ps1 -To "test@domain.com"
```

Then run a real export:

```powershell
# Standard export (existing behavior)
.\RVToolsDump.ps1

# All export modes configured per host in HostList.psd1
.\RVToolsDump.ps1
```

## 🚀 Export Mode Options (Enhanced in v3.1.0)

### **Standard Export Mode**

```powershell
@{ Name = 'vcenter01.contoso.local'; ExportMode = 'Normal' }
```

- Full RVTools export with all 26 tabs
- Best for comprehensive data collection
- File size: 200-500KB typically

### **Chunked Export Mode**

```powershell
@{ Name = 'vcenter-large.contoso.local'; ExportMode = 'Chunked' }
```

- Individual tab exports merged into single file
- Best for large environments (10,000+ VMs)
- Memory efficient, fault tolerant

### **Single-Tab Export Mode (NEW)**

```powershell
@{ Name = 'vcenter02.contoso.local'; ExportMode = 'vLicense' }
@{ Name = 'vcenter03.contoso.local'; ExportMode = 'vInfo' }
@{ Name = 'vcenter04.contoso.local'; ExportMode = 'vHost' }
```

- Export only specific tab data
- Ultra-lightweight (9-10KB files)
- Perfect for targeted monitoring and testing

### How Chunked Export Works

1. **Individual Tab Exports**: Exports each of the 26 RVTools tabs separately (vInfo, vCPU, vMemory, vDisk, etc.)
2. **Memory Efficiency**: Each tab uses less memory than full export, reducing crash risk
3. **Fault Tolerance**: Continues even if some tabs fail due to crashes
4. **Smart Merging**: Uses **ImportExcel PowerShell module** to combine successful tabs into single consolidated file
   - **No Excel Installation Required**: Uses ImportExcel module instead of Excel COM automation
   - **Server-Friendly**: Works on Windows Server Core and containers
   - **Enhanced Reliability**: No COM object management or Excel process issues
   - Automatically excludes duplicate vMetaData tabs (keeps only the first one)
   - Handles empty worksheets gracefully (shows warnings but continues processing)
   - Maintains all unique data while reducing file complexity
5. **Automatic Cleanup**: Removes all temporary tab files after merge completion (regardless of success/failure)

### When to Use Each Mode

- **Normal Mode**: Default for most environments under 5,000 VMs
- **Chunked Mode**: Large environments with memory issues or partial data acceptable
- **Single-Tab Mode**: Connectivity testing, license auditing, targeted monitoring
- **Server Deployment**: No Excel installation required (uses ImportExcel module)

### Per-Host Export Mode Configuration

You can configure export mode on a per-host basis in your `HostList.psd1` file, which is ideal for scheduled operations where only specific large environments need special handling:

```powershell
@{
    Hosts = @(
        # Standard hosts use normal export mode by default
        'vcenter01.contoso.local'
        'vcenter02.contoso.local'
        
        # Large hosts can be configured for chunked export
        @{ Name = 'vcenter-large.contoso.local'; Username = 'svc_rvtools@contoso.local'; ExportMode = 'Chunked' }
        @{ Name = 'vcenter-huge.contoso.local'; Username = 'admin@vsphere.local'; ExportMode = 'Chunked' }
        
        # Single-tab exports for specific monitoring
        @{ Name = 'vcenter-license.contoso.local'; Username = 'svc_rvtools@contoso.local'; ExportMode = 'vLicense' }
        @{ Name = 'vcenter-info.contoso.local'; Username = 'svc_rvtools@contoso.local'; ExportMode = 'vInfo' }
        
        # Mix all modes in the same configuration
        @{ Name = 'vcenter-prod.contoso.local'; Username = 'prod_service@contoso.local'; ExportMode = 'Normal' }
    )
}
```

## Testing & Connectivity

### Enhanced Connectivity Testing

The toolkit includes a comprehensive connectivity testing script that leverages the new single-tab export functionality:

```powershell
# Test credential retrieval only
.\test\Test-RVToolsConnectivity.ps1 -TestType CredentialOnly

# Test basic RVTools connection (recommended)
.\test\Test-RVToolsConnectivity.ps1 -TestType QuickConnect

# Full validation using vLicense single-tab export (comprehensive)
.\test\Test-RVToolsConnectivity.ps1 -TestType FullValidation

# Test specific hosts only
.\test\Test-RVToolsConnectivity.ps1 -TestType FullValidation -HostFilter "*license*"
```

The **FullValidation** mode now uses the new `vLicense` single-tab export functionality to provide real RVTools testing while minimizing data transfer and execution time.

## Security Considerations

- **Password Encryption**: Uses RVTools' DPAPI-based encryption (same user/computer only)
- **Secure Secret Storage**: Microsoft Graph ClientSecret stored encrypted in SecretManagement vault
- **No Plaintext Secrets**: Configuration files contain only secret names, not actual secrets
- **Least Privilege**: Use a dedicated service account with minimal vCenter permissions
- **Credential Storage**: All credentials are encrypted in SecretManagement vault
- **Network Security**: Ensure secure communication to vCenter
- **File Permissions**: Restrict access to the toolkit directory
- **Secret Rotation**: Use credential management scripts to update rotated passwords/secrets

## Recent Updates

### August 2025 v3.1.0 - Single-Tab Export Enhancement

- **🎯 Granular Export Control**: Export specific RVTools tabs (e.g., 'vLicense', 'vInfo', 'vHost')
- **⚡ Performance Benefits**: Single-tab exports are 350x smaller than full exports
- **🧪 Enhanced Testing**: Refactored connectivity testing to use vLicense exports
- **🔄 Smart Integration**: Seamlessly integrated with existing Normal/Chunked modes
- **📁 Professional File Naming**: hostname-timestamp-tabname.xlsx format
- **✅ Production Validated**: Successfully tested with multiple enterprise environments

### August 2025 v3.0.0 - Professional Module Architecture

- **🏗️ Complete Module**: Professional RVToolsModule with 10 public and 5 private functions
- **📊 ImportExcel Integration**: Eliminated Microsoft Excel dependency for server deployments
- **🔄 Massive Refactoring**: ~200+ lines of duplicate code eliminated through shared functions
- **✅ Enhanced Validation**: Custom validation attributes and enterprise-grade error handling
- **🚀 Pipeline Support**: Full ValueFromPipeline support for bulk operations

### August 2025 v2.1.0 - RVTools Configuration Fix & Utilities

- **🔧 Log4Net Fix**: Added Fix-RVToolsLog4NetConfig.ps1 utility to resolve RVTools CLI issues
- **📁 Utilities Organization**: New utilities/ folder for maintenance scripts
- **✅ Production Impact**: Fixed command-line failures, enabling successful RVTools operations

## Requirements

- PowerShell 7+ (recommended) or Windows PowerShell 5.1
- RVTools 4.0+ installed (validated with Dell RVTools CLI standards)
- **RVToolsModule v3.3.0** (included in this toolkit)
- Microsoft.PowerShell.SecretManagement module
- Microsoft.PowerShell.SecretStore module
- ImportExcel module (for chunked export merging - no Excel installation required)
- Microsoft.Graph.Authentication and Microsoft.Graph.Users.Actions modules (if using Microsoft Graph email)
- Windows DPAPI (for RVTools password encryption)

## Module Usage Examples

### Advanced Pipeline Operations

```powershell
# Import the module directly for advanced usage
Import-Module .\RVToolsModule

# Process multiple hosts with different export modes
@(
    @{ HostName = 'vcenter01'; ExportMode = 'Normal' }
    @{ HostName = 'vcenter02'; ExportMode = 'vLicense' }
    @{ HostName = 'vcenter03'; ExportMode = 'vInfo' }
) | Invoke-RVToolsExport -ConfigPath $config

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

# Single-tab export for specific use cases
Invoke-RVToolsExport -HostName 'vcenter01' -ExportMode 'vLicense' -NoEmail
```

## File Structure

```plaintext
RVToolsDailyDump/
├── RVToolsDump.ps1                       # Main export script (enhanced with single-tab support)
├── Set-RVToolsCredentials.ps1            # vCenter credential management (enhanced)
├── Set-MicrosoftGraphCredentials.ps1     # Microsoft Graph secret management (enhanced)
├── Initialize-RVToolsDependencies.ps1    # Setup and validation (enhanced)
├── RVToolsModule/                        # Professional PowerShell module (fully utilized)
│   ├── RVToolsModule.psd1                # Module manifest (v3.3.0)
│   ├── RVToolsModule.psm1                # Module loader
│   ├── Public/                           # 10 exported functions
│   │   ├── Invoke-RVToolsExport.ps1      # Main export cmdlet with single-tab support
│   │   ├── Import-RVToolsConfiguration.ps1 # Configuration loading with template fallback
│   │   ├── Get-RVToolsCredentialFromVault.ps1 # Secure credential retrieval
│   │   ├── Write-RVToolsLog.ps1          # Standardized logging
│   │   ├── Test-RVToolsVault.ps1         # Vault validation
│   │   ├── Resolve-RVToolsPath.ps1       # Smart path resolution
│   │   ├── New-RVToolsDirectory.ps1      # Directory creation with error handling
│   │   ├── Get-RVToolsEncryptedPassword.ps1 # DPAPI password encryption
│   │   ├── Get-RVToolsSecretName.ps1     # Secret name pattern generation
│   │   └── Merge-RVToolsExcelFiles.ps1   # Excel file merging for chunked exports
│   ├── Private/                          # 6 internal helper functions
│   │   ├── Get-RVToolsTabDefinitions.ps1 # Tab definitions and command mapping
│   │   ├── Invoke-RVToolsChunkedExport.ps1
│   │   ├── Invoke-RVToolsStandardExport.ps1
│   │   ├── Invoke-RVToolsSingleTabExport.ps1  # NEW: Single-tab export function
│   │   ├── Send-RVToolsGraphEmail.ps1
│   │   └── ValidationAttributes.ps1
├── shared/
│   ├── Configuration-Template.psd1       # Config template
│   ├── HostList-Template.psd1            # Host list template
│   ├── Configuration.psd1                # Live config (ignored by Git)
│   └── HostList.psd1                     # Live host list (ignored by Git)
├── test/                                 # Enhanced test suite
│   ├── Run-Tests.ps1                     # Main test runner
│   ├── Test-Configuration.ps1            # Configuration validation tests
│   ├── Test-Credentials.ps1              # Credential management tests
│   ├── Test-RVToolsConnectivity.ps1      # Enhanced connectivity tests with single-tab support
│   └── Test-RVToolsPasswordEncryption.ps1 # Password encryption tests
├── utilities/                            # Maintenance and troubleshooting
│   ├── Fix-RVToolsLog4NetConfig.ps1      # RVTools configuration fix utility
│   └── README.md                         # Utilities documentation
├── exports/                              # Export files (ignored by Git)
└── logs/                                 # Log files (ignored by Git)
```

## License

This toolkit is provided as-is for internal use. Customize as needed for your environment.

**Author**: Alfred Angelov  
**Version**: 3.3.0  
**Date**: September 14, 2025
