@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'RVToolsModule.psm1'

    # Version number of this module.
    ModuleVersion = '3.2.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'

    # Author of this module
    Author = 'Alfred Angelov'

    # Description of the functionality provided by this module
    Description = 'Professional PowerShell module for automating RVTools exports across multiple vCenter servers with advanced features including pipeline support, comprehensive validation, and secure credential management.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # ClrVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ModuleName = 'Microsoft.PowerShell.SecretManagement'; ModuleVersion = '1.1.0'},
        @{ModuleName = 'Microsoft.PowerShell.SecretStore'; ModuleVersion = '1.0.0'}
    )

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        # Public functions
        'Write-RVToolsLog',
        'Import-RVToolsConfiguration',
        'Test-RVToolsVault',
        'Get-RVToolsCredentialFromVault',
        'Get-RVToolsSecretName',
        'Get-RVToolsEncryptedPassword',
        'Resolve-RVToolsPath',
        'New-RVToolsDirectory',
        'Invoke-RVToolsExport',
        'Merge-RVToolsExcelFiles'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('RVTools', 'VMware', 'vCenter', 'Automation', 'SecretManagement', 'Pipeline', 'Validation', 'Enterprise')

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
3.2.0 - Testing Infrastructure Enhancement
- Added comprehensive Excel merge test framework (Test-RVToolsExcelMerge.ps1)
- Enhanced testing infrastructure with mock data generation for all 26 RVTools tabs
- Integrated Excel merge testing into main test runner (Run-Tests.ps1)
- Security improvements: sanitized company domain references in documentation
- Comprehensive validation of Merge-RVToolsExcelFiles functionality
- Mock data generation for realistic testing scenarios (VMs, hosts, clusters, licenses)
- Flexible test modes: QuickTest (3 tabs) and Full Test (26 tabs)
- vMetaData deduplication testing and validation framework
- Enhanced troubleshooting documentation with test utilities
- Production-ready testing infrastructure for Excel merge operations

3.1.0 - Single-Tab Export Enhancement
- Added granular single-tab export capability (e.g., 'vLicense', 'vInfo', 'vHost')
- Enhanced Invoke-RVToolsExport to support tab names as ExportMode parameter
- New private function Invoke-RVToolsSingleTabExport for targeted data collection
- Perfect for lightweight testing, license auditing, and specific troubleshooting
- Performance benefits: single-tab exports are 350x smaller than full exports
- Smart routing automatically detects and handles single-tab export modes
- Proper file naming convention: hostname-timestamp-tabname.xlsx format
- Refactored Test-RVToolsConnectivity.ps1 to use vLicense exports for validation
- Enhanced connectivity testing with real RVTools functionality
- Maintains full backward compatibility with existing export modes

3.0.0 - Phase 3: Professional Module with ImportExcel Integration
- Added ImportExcel module integration for server-friendly Excel processing
- Eliminated Microsoft Excel installation requirement for chunked exports
- Enhanced Merge-RVToolsExcelFiles function with ImportExcel support
- Improved error handling for empty worksheets and partial exports
- Added comprehensive pipeline support for bulk operations
- Implemented advanced parameter validation with custom attributes
- Added support for InfoOnly and Custom export modes
- Enhanced help documentation with detailed examples
- Created comprehensive Pester test suite
- Improved error handling and validation
- Added custom validation classes for hostname, file paths, and RVTools tabs
- Performance optimizations for large-scale operations
- Production tested with large environments (19/26 tabs successfully processed)
- Ready for PowerShell Gallery publication

2.1.0 - Phase 2: Modularized Main Script
- Added Invoke-RVToolsExport cmdlet as main entry point
- Extracted complex functions into private module functions
- Improved parameter validation and pipeline support
- Enhanced error handling and result objects
- Maintained full backward compatibility

2.0.0 - Initial modularized version
- Extracted common functions from individual scripts
- Centralized logging, configuration, and credential management
- Maintained backward compatibility with existing scripts
'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
