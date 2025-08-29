# RVTools Daily Dump Toolkit

A reliable, configuration-driven PowerShell toolkit for automating RVTools exports across multiple vCenter servers with secure credential management and optional SharePoint integration. **Now with validated Dell RVTools CLI integration and chunked export mode for large environments.**

## Features

- **Chunked Export Mode**: Handles large vCenter environments where standard export crashes due to memory issues
- **Secure Credential Management**: Uses PowerShell SecretManagement for unattended operation
- **Password Encryption**: Leverages RVTools' own DPAPI-based password encryption (no plaintext passwords)
- **Configuration-Driven**: Separate configuration and host list files (templates provided)
- **Reliable Operation**: DryRun capability, verbose logging, and error handling
- **Validated RVTools Integration**: Uses Dell's recommended CLI approach with proper batch processing
- **Email Summaries**: Optional email reports with run status and logs
- **SharePoint Integration**: Upload exports to SharePoint for Teams access (optional)
- **Easy Onboarding**: Automated dependency validation and vault initialization
- **Multi-vCenter Support**: Process multiple vCenter servers with individual or shared credentials

## Quick Start

### 1. Initialize Dependencies

Run the initialization script to install required modules and set up SecretManagement:

```powershell
.\Initialize-RVToolsDependencies.ps1
```

This will:

- Install Microsoft.PowerShell.SecretManagement and SecretStore modules
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
- Enable SharePoint integration if needed

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

```Plain text
RVToolsDailyDump/
├── RVToolsDump.ps1                     # Main export script
├── Set-RVToolsCredentials.ps1          # Credential management
├── Initialize-RVToolsDependencies.ps1  # Setup and validation
├── Upload-ToSharePoint.ps1             # SharePoint integration
├── shared/
│   ├── Configuration-Template.psd1     # Config template
│   ├── HostList-Template.psd1          # Host list template
│   ├── Configuration.psd1              # Live config (ignored by Git)
│   └── HostList.psd1                   # Live host list (ignored by Git)
├── exports/                            # Export files (ignored by Git)
├── logs/                               # Log files (ignored by Git)
└── docs/
    └── WishList.md                     # Feature roadmap
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

### SharePoint Integration

- `Enabled`: Enable SharePoint uploads
- `SiteUrl`: SharePoint site URL
- `DocumentLibrary`: Target document library
- `CredentialSecret`: Name of stored SharePoint credential

## Advanced Usage

### Credential Management

```powershell
# Update a specific credential (e.g., after password rotation)
.\Set-RVToolsCredentials.ps1 -HostName "vcenter01.contoso.local" -Username "svc_rvtools"

# Remove a stored credential (now supports username specification)
.\Set-RVToolsCredentials.ps1 -RemoveCredential -HostName "vcenter01.contoso.local" -Username "svc_rvtools"

# List all stored credentials (improved parsing for complex hostnames)
.\Set-RVToolsCredentials.ps1 -ListCredentials
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

### SharePoint Integration commands

Store SharePoint credentials:

```powershell
# Store SharePoint service account credentials
.\Set-RVToolsCredentials.ps1 -HostName "SharePoint" -Username "svc_sharepoint@contoso.com"
```

Upload exports to SharePoint:

```powershell
# Upload today's exports
.\Upload-ToSharePoint.ps1

# Upload a specific file
.\Upload-ToSharePoint.ps1 -ExportFile "vcenter01-20250819_143022.xlsx"

# Upload all export files
.\Upload-ToSharePoint.ps1 -UploadAll
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
- **Least Privilege**: Use a dedicated service account with minimal vCenter permissions
- **Credential Storage**: Credentials are encrypted in SecretManagement vault
- **Network Security**: Ensure secure communication to vCenter and SharePoint
- **File Permissions**: Restrict access to the toolkit directory
- **Password Rotation**: Use Set-RVToolsCredentials.ps1 to update rotated passwords

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

### SharePoint Issues

- Verify PnP.PowerShell module installation
- Check SharePoint permissions for service account
- Validate site URL and document library name

### Debug Logging

Enable debug logging in configuration:

```powershell
Logging = @{
    EnableDebug = $true
    LogLevel = 'DEBUG'
}
```

## Recent Updates

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
- Microsoft.PowerShell.SecretManagement module
- Microsoft.PowerShell.SecretStore module
- PnP.PowerShell module (for SharePoint integration)
- Windows DPAPI (for RVTools password encryption)

## License

This toolkit is provided as-is for internal use. Customize as needed for your environment.
