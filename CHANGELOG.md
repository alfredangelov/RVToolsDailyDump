# RVTools Daily Dump Toolkit - Changelog

## [1.4.2] - August 29, 2025 - Unique Log Files Per Run

### 🔧 Logging Enhancement

#### Unique Log Files for Each Execution

- **Improved Feature**: Log files now include timestamp (YYYYMMDD_HHMMSS) for unique naming per run
- **Email Enhancement**: Email reports now contain only logs from the current run, not entire day
- **Format Change**: From `RVTools_RunLog_YYYYMMDD.txt` to `RVTools_RunLog_YYYYMMDD_HHMMSS.txt`
- **Benefits**:
  - Each run generates its own isolated log file
  - Email reports are cleaner and more focused
  - Better troubleshooting with run-specific logs
  - No more cumulative daily logs in email reports

### 🛠️ Technical Improvements

- **Modified**: Log file naming in `RVToolsDump.ps1` to include hours, minutes, and seconds
- **Enhanced**: Email reports now contain only relevant logs for the specific execution
- **Maintained**: All existing functionality while improving log organization

## [1.4.1] - August 29, 2025 - Secure Microsoft Graph Secret Storage

### 🔒 Security Enhancement

#### Secure ClientSecret Storage in SecretManagement Vault

- **New Feature**: `Set-MicrosoftGraphCredentials.ps1` helper script for secure secret management
- **Security Improvement**: Microsoft Graph ClientSecret now stored encrypted in SecretManagement vault
- **Configuration Change**: Use `ClientSecretName` instead of plaintext `ClientSecret` in configuration
- **Benefits**:
  - No plaintext secrets in configuration files
  - Encrypted storage using Windows DPAPI
  - Centralized secret management with existing credential infrastructure
  - Easy secret rotation and maintenance

#### Enhanced Microsoft Graph Integration

- **Improved**: Parameter validation for ClientSecret vs ClientSecretName usage
- **Fixed**: Hashtable property access issue that caused parameter binding errors
- **Added**: Comprehensive secret management operations (Store/Update/Remove/Show/List)
- **Enhanced**: Configuration validation to ensure proper secret storage setup

### 🛠️ Technical Improvements 1.4.2

#### New Helper Script: Set-MicrosoftGraphCredentials.ps1

```powershell
# Store ClientSecret securely in vault
.\Set-MicrosoftGraphCredentials.ps1 -Store -ClientSecret 'your-secret'

# Update existing ClientSecret
.\Set-MicrosoftGraphCredentials.ps1 -Update -ClientSecret 'new-secret'

# Show configuration (without revealing secret)
.\Set-MicrosoftGraphCredentials.ps1 -Show

# List all vault secrets
.\Set-MicrosoftGraphCredentials.ps1 -List

# Remove ClientSecret from vault
.\Set-MicrosoftGraphCredentials.ps1 -Remove
```

#### Configuration Migration

**Before (Insecure)**:

```powershell
Email = @{
    Method    = 'MicrosoftGraph'
    TenantId  = 'tenant-id'
    ClientId  = 'client-id'
    ClientSecret = 'plaintext-secret-here'  # Security risk!
}
```

**After (Secure)**:

```powershell
Email = @{
    Method    = 'MicrosoftGraph'
    TenantId  = 'tenant-id'
    ClientId  = 'client-id'
    ClientSecretName = 'MicrosoftGraph-ClientSecret'  # References vault secret
}
```

#### Function Improvements

- **Enhanced**: `Send-MicrosoftGraphEmail` function parameter handling
- **Fixed**: Property access syntax to use hashtable notation (`$config['key']`) instead of object notation (`$config.key`)
- **Improved**: Error handling for missing or invalid ClientSecret configuration
- **Added**: Automatic secret retrieval from vault during email sending

### 🔧 Bug Fixes

#### Microsoft Graph Email Parameter Binding

- **Fixed**: "The property 'ClientSecret' cannot be found on this object" error
- **Root Cause**: PowerShell property access on hashtables where property doesn't exist
- **Solution**: Changed from `$emailCfg.ClientSecret` to `$emailCfg['ClientSecret']`
- **Result**: Proper handling of optional ClientSecret vs ClientSecretName parameters

### ✅ Validation & Testing

**Security Testing**:

- ✅ ClientSecret successfully stored in encrypted vault
- ✅ Configuration files contain no plaintext secrets
- ✅ Email sending works with vault-retrieved secrets
- ✅ Secret rotation process validated

**Integration Testing**:

- ✅ Microsoft Graph email sending confirmed working
- ✅ RVTools exports continue functioning normally
- ✅ End-to-end workflow tested successfully

### 📚 Documentation Updates (1.4.1)

- **Updated**: README.md with secure Microsoft Graph setup instructions
- **Added**: Security considerations section highlighting secret storage improvements
- **Enhanced**: Credential management section with Microsoft Graph specific commands
- **Added**: File structure documentation showing new helper script

### 🔄 Migration Guide

#### For Existing Microsoft Graph Users

1. **Store your ClientSecret securely**:

   ```powershell
   .\Set-MicrosoftGraphCredentials.ps1 -Store -ClientSecret 'your-current-secret'
   ```

2. **Update your Configuration.psd1**:

   ```powershell
   # Replace this line:
   ClientSecret = 'your-secret'
   
   # With this line:
   ClientSecretName = 'MicrosoftGraph-ClientSecret'
   ```

3. **Verify the setup**:

   ```powershell
   .\Set-MicrosoftGraphCredentials.ps1 -Show
   ```

4. **Test email functionality**:

   ```powershell
   .\RVToolsDump.ps1 -DryRun  # Test configuration
   ```

### 🎯 Benefits Summary

- **Enhanced Security**: No plaintext secrets in configuration files
- **Consistent Management**: Same vault used for all credentials (vCenter + Microsoft Graph)
- **Easy Maintenance**: Simple secret rotation with dedicated helper script
- **Audit Trail**: SecretManagement provides better tracking of secret access
- **Future-Proof**: Foundation for additional secret types (SharePoint, etc.)

## [1.4.0] - August 29, 2025 - Microsoft Graph Email & Chunked Export Features

### 🚀 Major New Features

#### Chunked Export Mode for Large Environments

- **New Feature**: `-ChunkedExport` parameter for `RVToolsDump.ps1`
- **Purpose**: Handles large vCenter environments where standard export crashes due to memory issues
- **How it works**: Exports each RVTools tab individually (26 tabs total), then merges into single Excel file
- **Benefits**:
  - Memory-efficient processing (one tab at a time)
  - Fault-tolerant (continues even if some tabs fail)
  - Same end result as standard export
  - Automatic cleanup of temporary files

#### Per-Host Export Mode Configuration

- **New Feature**: `ExportMode` property in `HostList.psd1` configuration
- **Purpose**: Configure export mode on a per-host basis for mixed environments
- **Options**: `'Normal'` (default) or `'Chunked'` for each individual host
- **Benefits**:
  - Ideal for scheduled operations (set once in configuration)
  - Mix small and large vCenters in the same run
  - No need to remember which hosts need chunked export
  - Maintenance-free automation

#### Enhanced Credential Management Features

- **Fixed**: Username parameter support for credential removal
- **Improved**: Secret name parsing for hosts/usernames containing dashes
- **Enhanced**: Better error handling and validation

#### Microsoft Graph Email Integration

- **New Feature**: Microsoft Graph email method for modern email sending
- **Purpose**: Replace deprecated Send-MailMessage with secure OAuth2 authentication
- **Configuration**: New `Method = 'MicrosoftGraph'` option in email configuration
- **Benefits**:
  - OAuth2 authentication (more secure than SMTP)
  - Firewall-friendly (HTTPS only, no SMTP ports needed)
  - Integrated with Microsoft 365 environments
  - Better audit logging and security controls
- Free with existing M365 licensing

### 🛠️ Technical Improvements (1.4.0)

#### Chunked Export Details

**Individual Tab Commands**:

- 26 separate RVTools export commands (vInfo, vCPU, vMemory, vDisk, etc.)
- Each tab exported separately to reduce memory usage

**Excel File Merging**:

- Smart merging avoids duplicate vMetaData tabs (keeps only the first one)
- Proper COM object cleanup and error handling
- Preserves all data while reducing file complexity
- Detailed exit code interpretation (connection failures vs crashes vs other errors)

**Smart Merging**:

- Uses Excel COM object to merge worksheets
- First successful file becomes base workbook
- Additional worksheets appended from other successful exports
- Automatic cleanup of all temporary tab files (including failed/stub files)

**Enhanced Logging**:

- Tab-by-tab success/failure reporting
- Detailed exit code explanations (connection failed, crash, other)
- Summary showing successful vs failed tab counts
- Clear indication of partial success scenarios

#### Enhanced Dependency Initialization

**Microsoft Graph Module Detection**:

- Automatically detects when Microsoft Graph email is configured
- Installs `Microsoft.Graph.Authentication` and `Microsoft.Graph.Mail` modules when needed
- Validates module availability during initialization
- Conditional installation based on email method configuration

**Improved Validation**:

- Enhanced initialization summary with Microsoft Graph module status
- Clear warnings when required modules are missing
- Supports both SMTP and Microsoft Graph email configurations

#### Credential Management Improvements

**Username Support for Removal**:

```powershell
# Now supports specifying username when removing credentials
.\Set-RVToolsCredentials.ps1 -RemoveCredential -HostName "host" -Username "user"
```

**Improved Secret Name Parsing**:

- Fixed parsing of secret names containing dashes in hostname or username
- Now splits at last dash instead of first dash for correct host/username separation

### 📊 Usage Examples

#### Chunked Export

```powershell
# Standard export (existing behavior)
.\RVToolsDump.ps1

# Chunked export for large environments with memory issues
.\RVToolsDump.ps1 -ChunkedExport

# Test chunked export without actually running RVTools
.\RVToolsDump.ps1 -ChunkedExport -DryRun -WhatIf
```

#### Per-Host Configuration Examples

```powershell
# Configure mixed normal and chunked export modes in HostList.psd1
@{
    Hosts = @(
        # Small environments use normal export (default)
        'vcenter01.contoso.local'
        'vcenter02.contoso.local'
        
        # Large environments configured for chunked export
        @{ Name = 'vcenter-large.contoso.local'; Username = 'svc_rvtools@contoso.local'; ExportMode = 'Chunked' }
        @{ Name = 'vcenter-huge.contoso.local'; Username = 'admin@vsphere.local'; ExportMode = 'Chunked' }
        
        # Explicit normal mode specification
        @{ Name = 'vcenter-prod.contoso.local'; Username = 'prod_service@contoso.local'; ExportMode = 'Normal' }
    )
}

# Then run normally - export modes are automatically applied per host
.\RVToolsDump.ps1
```

#### Enhanced Credential Management

```powershell
# Remove credential with specific username
.\Set-RVToolsCredentials.ps1 -RemoveCredential -HostName "vcenter.domain.com" -Username "specific.user"

# List credentials (now shows correct parsing of complex hostnames)
.\Set-RVToolsCredentials.ps1 -ListCredentials
```

#### Microsoft Graph Email Configuration

```powershell
# Configure Microsoft Graph email in Configuration.psd1 (Secure version)
Email = @{
    Enabled   = $true
    Method    = 'MicrosoftGraph'  # Options: 'SMTP', 'MicrosoftGraph'
    From      = 'rvtools@contoso.com'
    To        = @('reports@contoso.com')
    
    # Microsoft Graph Configuration (Secure)
    TenantId         = 'your-tenant-id-guid'
    ClientId         = 'your-client-id-guid'
    ClientSecretName = 'MicrosoftGraph-ClientSecret'  # Stored securely in vault
}

# Store the ClientSecret separately using the helper script:
# .\Set-MicrosoftGraphCredentials.ps1 -Store -ClientSecret 'your-actual-client-secret'

# Traditional SMTP configuration still supported
Email = @{
    Enabled   = $true
    Method    = 'SMTP'  # Default method for backward compatibility
    From      = 'rvtools@contoso.com'
    To        = @('reports@contoso.com')
    SmtpServer= 'smtp.contoso.com'
    Port      = 587
    UseSsl    = $true
}
```

### 🔧 Bug Fixes & Improvements

#### Chunked Export Reliability

- **Fixed**: Excel merge error when no worksheets exist (creates base from first successful file)
- **Fixed**: Cleanup of stub files created by crashed exports
- **Enhanced**: Pattern-based cleanup removes all tab files after merge completion
- **Improved**: Distinguishes between different failure types (connection, crash, other)

#### Status Reporting

- **Enhanced**: Detailed status messages showing successful/failed tab counts
- **Added**: Specific exit code interpretation and logging
- **Improved**: Clear indication of partial success scenarios

### ✅ Testing & Validation

**Chunked Export Testing**:

- Successfully processed large environment with 20,000+ objects
- Handled tab crashes gracefully (vNIC and vSwitch tabs failed due to memory)
- Generated consolidated Excel file with multiple successful tabs
- Automatic cleanup removed all temporary files

**Credential Management Testing**:

- Verified username parameter works for credential removal
- Tested complex hostnames with dashes (e.g., "server-host01.domain.local")
- Confirmed proper secret name parsing and credential listing

### 📚 Documentation & Migration

- **Updated**: README.md with chunked export usage examples
- **Added**: Troubleshooting section for large environment scenarios
- **Enhanced**: Credential management examples with username specification
- **Added**: Performance considerations and memory optimization guidance

## [1.2.0] - August 19, 2025 - RVTools CLI Integration Fixes

### 🎉 Major Fixes - RVTools Now Working Correctly

#### Fixed RVTools CLI Execution

- **Issue**: RVTools was opening GUI instead of running batch exports
- **Solution**: Implemented Dell's recommended CLI approach using `-c ExportAll2xlsx`
- **Reference**: Based on official `RVToolsBatchMultipleVCs.ps1` from Dell

#### Fixed Export File Creation

- **Issue**: Export files not being created despite successful execution
- **Solution**: Fixed path quoting for directories containing spaces, proper `-d`/`-f` parameter usage
- **Result**: Export files now correctly created in configured directory

#### Enhanced Process Management

- **Changed**: From direct `&` execution to `Start-Process` with `-NoNewWindow -Wait -PassThru`
- **Added**: Working directory change to RVTools folder during execution
- **Improved**: Exit code handling with specific detection of connection failures (-1)

### ✅ Validation Results

Successfully tested with production environment:

- **Multiple vCenter servers**: vcenter01, vcenter02
- **Real export generation**: 267-338KB Excel files with actual VMware data
- **Credential integration**: SecretManagement vault working correctly
- **Batch processing**: No GUI interference, true unattended operation

### 🔧 Additional Improvements

#### HostList Format Enhancement

- **Changed**: Array format `@()` to hashtable format `@{ Hosts = @() }`
- **Reason**: Better PowerShell Data File compatibility
- **Updated**: All consuming scripts to handle new format

#### Credential Management Fixes  

- **Fixed**: Username validation error when using default username from config
- **Enhanced**: Error handling for empty usernames
- **Improved**: List credentials functionality (removed non-existent LastModified property)

#### Test Framework

- **Added**: Comprehensive test suite (`test/` folder)
- **Tests**: Configuration validation, credential management, password encryption
- **Runner**: Main test runner with selective test execution

### 📚 Documentation Updates

- **Updated**: README.md with validated RVTools integration details
- **Added**: Troubleshooting section with specific fixes
- **Enhanced**: Examples showing successful execution output
- **Added**: Recent updates section documenting all changes

## Previous Versions

### [1.1.0] - Earlier August 2025

- Initial SecretManagement integration
- RVTools password encryption support
- Configuration-driven approach
- SharePoint integration
- Email functionality

### [1.0.0] - Initial Release

- Basic RVTools export automation
- Multi-vCenter support
- Logging framework
- Template-based configuration

---

## Migration Notes

### From 1.1.x to 1.2.0

1. **HostList Format Change**:

   ```powershell
   # Old format (will not work)
   @(
       'vcenter01.domain.com'
   )
   
   # New format (required)
   @{
       Hosts = @(
           'vcenter01.domain.com'
       )
   }
   ```

2. **No credential changes needed** - existing stored credentials work unchanged

3. **Configuration files** - no changes required to Configuration.psd1

4. **RVTools path** - verify path in configuration points to RVTools.exe

### Validation Steps After Upgrade

```powershell
# 1. Test configuration parsing
.\test\Test-Configuration.ps1

# 2. Verify credentials
.\Set-RVToolsCredentials.ps1 -ListCredentials

# 3. Dry run test
.\RVToolsDump.ps1 -DryRun

# 4. Real execution test
.\RVToolsDump.ps1
```

---

**Status**: ✅ **PRODUCTION READY** - Successfully validated with multiple production vCenter servers
