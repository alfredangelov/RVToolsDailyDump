# RVToolsModule Documentation

## Project Overview

This directory contains comprehensive documentation for the RVTools PowerShell Module project, which underwent a complete 3-phase modularization transformation from individual scripts to a professional enterprise-grade PowerShell module.

## Phase Documentation

### [Phase 1: Extract Common Functions](Phase1-Summary.md)

#### Version: 2.0.1

- **Objective**: Extract and centralize duplicate functions across 5 scripts
- **Achievement**: ~60% code reduction through function consolidation
- **Key Results**: 8 common functions extracted into centralized module
- **Impact**: Single source of truth for logging, configuration, and credential management

### [Phase 2: Main Script Modularization](Phase2-Summary.md)

#### Version: 2.1.0

- **Objective**: Complete refactoring of main script to leverage module functions
- **Achievement**: 73% code reduction (302 → 82 lines) by eliminating duplication
- **Key Results**: All export logic centralized in module functions
- **Impact**: Single point of maintenance for all complex operations

### [Phase 2 Refactoring Details](Refactoring-Summary-2.1.0.md)

#### Technical Implementation Summary

- **Complete refactoring documentation** for the main script transformation
- **Before/after analysis** showing specific improvements achieved
- **Detailed breakdown** of code elimination and function consolidation
- **Testing results** and compatibility verification

- **Objective**: Transform monolithic main script into modular architecture
- **Achievement**: 92% reduction in main script size (600+ lines → 50 lines)
- **Key Results**: Professional cmdlet interface with comprehensive business logic extraction
- **Impact**: Enterprise-grade functionality with chunked exports and enhanced error handling

### [Phase 3: Enhanced & Polished Professional Module](Phase3-Summary.md)

#### Version: 3.0.0

- **Objective**: Add advanced features and prepare for production deployment
- **Achievement**: Professional-grade module with comprehensive validation and testing
- **Key Results**: Pipeline support, custom validation, comprehensive test suite
- **Impact**: PowerShell Gallery ready module with enterprise features

## Quick Reference

### Module Evolution

```Plain Text
Original State (5 individual scripts)
├── 150+ lines of duplicate code
├── Inconsistent error handling
├── Manual configuration management
└── Limited reusability

Phase 1 (Centralized common functions)
├── Single module with 8 shared functions
├── Unified logging and configuration
├── Backward compatible integration
└── 60% code reduction achieved

Phase 2 (Modular architecture)
├── Professional cmdlet interface
├── Business logic extraction
├── Enhanced export capabilities
└── 92% main script reduction

Phase 3 (Professional polish)
├── Advanced parameter validation
├── Pipeline support
├── Comprehensive testing
└── Production-ready quality
```

### Key Benefits Achieved

| Aspect | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Code Duplication** | 150+ duplicate lines | 0 duplicate lines | 100% elimination |
| **Main Script Size** | 600+ lines | 50 lines | 92% reduction |
| **Function Count** | 1 monolithic | 13 focused functions | Better separation |
| **Test Coverage** | Manual only | Automated test suite | Professional QA |
| **Documentation** | Minimal | Comprehensive help | Enterprise ready |
| **Validation** | Basic | Advanced custom classes | Robust input handling |
| **Pipeline Support** | None | Full pipeline integration | Bulk operations |
| **Error Handling** | Basic | Comprehensive with recovery | Production quality |

### Usage Examples

#### Basic Operations

```powershell
# Import the module
Import-Module .\RVToolsModule\RVToolsModule.psd1

# Standard export
Invoke-RVToolsExport

# Test configuration
Invoke-RVToolsExport -DryRun

# Large environments
Invoke-RVToolsExport -ChunkedExport
```

#### Advanced Features (Phase 3)

```powershell
# Custom export modes
Invoke-RVToolsExport -ExportMode InfoOnly
Invoke-RVToolsExport -ExportMode Custom -CustomTabs @('vInfo', 'vCPU')

# Pipeline operations
@('vcenter1', 'vcenter2') | Invoke-RVToolsExport -NoEmail
Get-Content servers.txt | Invoke-RVToolsExport -ChunkedExport

# Professional help
Get-Help Invoke-RVToolsExport -Examples
```

## Project Structure

### Current Module Structure

```Plain Text
RVToolsModule/
├── RVToolsModule.psd1          # Module manifest (v3.0.0)
├── RVToolsModule.psm1          # Module loader
├── Public/                     # Exported functions (9 total)
│   ├── Invoke-RVToolsExport.ps1    # Main cmdlet
│   ├── Write-RVToolsLog.ps1        # Logging
│   ├── Import-RVToolsConfiguration.ps1 # Configuration
│   └── [6 other public functions]
└── Private/                    # Internal functions (4 total)
    ├── ValidationAttributes.ps1    # Custom validation classes
    ├── Merge-RVToolsExcelFiles.ps1 # Excel automation
    └── [2 other private functions]
```

### Supporting Documentation

- **[WishList.md](WishList.md)**: Future enhancement ideas

## Testing

### Test Suite Structure

```Plain Text
test/
├── Run-Tests.ps1               # Enhanced test runner
├── RVToolsModule.Tests.ps1     # Comprehensive Pester tests
├── Test-Configuration.ps1      # Configuration validation
├── Test-Credentials.ps1        # Credential management tests
└── Test-RVToolsPasswordEncryption.ps1 # Security tests
```

### Running Tests

```powershell
# All tests
.\test\Run-Tests.ps1

# Specific categories
.\test\Run-Tests.ps1 -TestSuite Module
.\test\Run-Tests.ps1 -TestSuite Configuration
```

## Deployment

### Prerequisites

- PowerShell 5.1+ or PowerShell 7+
- Microsoft.PowerShell.SecretManagement module
- Microsoft.PowerShell.SecretStore module
- ImportExcel module (for chunked export merging - no Excel installation required)
- RVTools installed (for production use)

### Enhanced Features (v2.0.1)

- **Server-Friendly Excel Processing**: Chunked export now uses ImportExcel module instead of Excel COM automation
- **No Microsoft Excel Required**: Eliminates expensive Office licensing for server deployments
- **Enhanced Reliability**: Better error handling and cleanup for partial export scenarios
- **Container Compatible**: Works on Windows Server Core and containerized environments

### Installation

```powershell
# Import the module
Import-Module .\RVToolsModule\RVToolsModule.psd1

# Verify installation
Get-Command -Module RVToolsModule
Get-Help Invoke-RVToolsExport
```

### Configuration

1. Copy template configurations: `shared/Configuration-Template.psd1` → `shared/Configuration.psd1`
2. Update host list: `shared/HostList-Template.psd1` → `shared/HostList.psd1`
3. Set up credentials: `.\Set-RVToolsCredentials.ps1`
4. Test configuration: `Invoke-RVToolsExport -DryRun`

## Support and Maintenance

### Troubleshooting

- Use `Invoke-RVToolsExport -DryRun -Verbose` for detailed diagnostics
- Check log files in the `logs/` directory
- Run test suite to validate installation: `.\test\Run-Tests.ps1`

### Updates and Enhancements

The modular architecture makes updates straightforward:

- **Function Updates**: Modify individual function files
- **New Features**: Add to appropriate Public or Private directories
- **Configuration**: Update template files and documentation

---

**Project**: RVToolsModule  
**Author**: Alfred Angelov
**Final Version**: 3.0.0  
**Documentation Updated**: August 30, 2025
