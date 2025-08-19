# RVTools Daily Dump Toolkit - Changelog

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
