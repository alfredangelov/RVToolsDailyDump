<#
.SYNOPSIS
    Test script for RVTools Excel merge functionality.

.DESCRIPTION
    This script generates mock Excel files for individual RVTools tabs and then
    tests the Merge-RVToolsExcelFiles function. It creates realistic test data
    to validate the merge functionality works correctly.

.PARAMETER TestDataPath
    Directory to create test files in. Defaults to temp directory.

.PARAMETER KeepTestFiles
    Keep test files after running tests for manual inspection.

.PARAMETER QuickTest
    Run a quick test with only 3 tabs instead of all tabs.

.EXAMPLE
    .\test\Test-RVToolsExcelMerge.ps1

.EXAMPLE
    .\test\Test-RVToolsExcelMerge.ps1 -KeepTestFiles -TestDataPath "C:\temp\rvtools-test"

.EXAMPLE
    .\test\Test-RVToolsExcelMerge.ps1 -QuickTest
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TestDataPath = (Join-Path $env:TEMP "RVToolsTest-$(Get-Date -Format 'yyyyMMdd-HHmmss')"),
    
    [Parameter()]
    [switch]$KeepTestFiles,
    
    [Parameter()]
    [switch]$QuickTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
try {
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $moduleRoot 'RVToolsModule') -Force -ErrorAction Stop
    Write-Host "✅ RVToolsModule loaded successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to load RVToolsModule: $($_.Exception.Message)"
    exit 1
}

# Check for ImportExcel module
if (-not (Get-Module -Name ImportExcel -ListAvailable)) {
    Write-Warning "ImportExcel module not found. Installing..."
    try {
        Install-Module ImportExcel -Scope CurrentUser -Force
    } catch {
        Write-Error "Failed to install ImportExcel module: $($_.Exception.Message)"
        exit 1
    }
}

Import-Module ImportExcel -Force

function Get-RVToolsTabDefinitions {
    <#
    .SYNOPSIS
        Returns the standard RVTools tab definitions for testing.
    #>
    return @(
        @{ Command = 'ExportvInfo2xlsx'; FileName = 'vInfo' },
        @{ Command = 'ExportvCPU2xlsx'; FileName = 'vCPU' },
        @{ Command = 'ExportvMemory2xlsx'; FileName = 'vMemory' },
        @{ Command = 'ExportvDisk2xlsx'; FileName = 'vDisk' },
        @{ Command = 'ExportvPartition2xlsx'; FileName = 'vPartition' },
        @{ Command = 'ExportvNetwork2xlsx'; FileName = 'vNetwork' },
        @{ Command = 'ExportvUSB2xlsx'; FileName = 'vUSB' },
        @{ Command = 'ExportvCD2xlsx'; FileName = 'vCD' },
        @{ Command = 'ExportvSnapshot2xlsx'; FileName = 'vSnapshot' },
        @{ Command = 'ExportvTools2xlsx'; FileName = 'vTools' },
        @{ Command = 'ExportvSource2xlsx'; FileName = 'vSource' },
        @{ Command = 'ExportvRP2xlsx'; FileName = 'vRP' },
        @{ Command = 'ExportvCluster2xlsx'; FileName = 'vCluster' },
        @{ Command = 'ExportvHost2xlsx'; FileName = 'vHost' },
        @{ Command = 'ExportvHBA2xlsx'; FileName = 'vHBA' },
        @{ Command = 'ExportvNIC2xlsx'; FileName = 'vNIC' },
        @{ Command = 'ExportvSwitch2xlsx'; FileName = 'vSwitch' },
        @{ Command = 'ExportvPort2xlsx'; FileName = 'vPort' },
        @{ Command = 'ExportdvSwitch2xlsx'; FileName = 'dvSwitch' },
        @{ Command = 'ExportdvPort2xlsx'; FileName = 'dvPort' },
        @{ Command = 'ExportvSC+VMK2xlsx'; FileName = 'vSC_VMK' },
        @{ Command = 'ExportvDatastore2xlsx'; FileName = 'vDatastore' },
        @{ Command = 'ExportvMultiPath2xlsx'; FileName = 'vMultiPath' },
        @{ Command = 'ExportvLicense2xlsx'; FileName = 'vLicense' },
        @{ Command = 'ExportvFileInfo2xlsx'; FileName = 'vFileInfo' },
        @{ Command = 'ExportvHealth2xlsx'; FileName = 'vHealth' }
    )
}

function New-MockVMData {
    <#
    .SYNOPSIS
        Generates mock VM data for testing
    #>
    param(
        [int]$VMCount = 5,
        [string]$HostPrefix = "testvcenter01"
    )
    
    $vms = @()
    for ($i = 1; $i -le $VMCount; $i++) {
        $vms += [PSCustomObject]@{
            VM = "TestVM-$($i.ToString('000'))"
            Powerstate = if ($i % 10 -eq 0) { "poweredOff" } else { "poweredOn" }
            Template = $false
            Config_File = "[datastore1] TestVM-$($i.ToString('000'))/TestVM-$($i.ToString('000')).vmx"
            Storage_Committed = (Get-Random -Minimum 5000000000 -Maximum 50000000000)
            Storage_Uncommitted = (Get-Random -Minimum 1000000000 -Maximum 10000000000)
            OS_Guest = @("Microsoft Windows Server 2019 (64-bit)", "Ubuntu Linux (64-bit)", "Red Hat Enterprise Linux 8 (64-bit)")[(Get-Random -Maximum 3)]
            Cluster = "TestCluster-$([Math]::Ceiling($i / 10))"
            Host = "$HostPrefix-esxi-$($i % 3 + 1).contoso.local"
            VI_SDK = "7.0.3"
            Datacenter = "TestDatacenter"
            Folder = "vm"
            Num_CPUs = @(1, 2, 4, 8)[(Get-Random -Maximum 4)]
            Memory = @(1024, 2048, 4096, 8192, 16384)[(Get-Random -Maximum 5)]
            NICs = (Get-Random -Minimum 1 -Maximum 3)
            Network_Names = "VM Network"
            Disks = (Get-Random -Minimum 1 -Maximum 4)
            Creation_Date = (Get-Date).AddDays(-(Get-Random -Maximum 365)).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    return $vms
}

function New-MockHostData {
    <#
    .SYNOPSIS
        Generates mock ESXi host data
    #>
    param(
        [int]$HostCount = 3,
        [string]$HostPrefix = "testvcenter01"
    )
    
    $hosts = @()
    for ($i = 1; $i -le $HostCount; $i++) {
        $hosts += [PSCustomObject]@{
            Host = "$HostPrefix-esxi-$i.contoso.local"
            State = "connected"
            Powerstate = "poweredOn"
            VM_Count = (Get-Random -Minimum 5 -Maximum 25)
            Sockets = @(1, 2)[(Get-Random -Maximum 2)]
            Cores = @(8, 12, 16, 20)[(Get-Random -Maximum 4)]
            Logical_Processors = @(16, 24, 32, 40)[(Get-Random -Maximum 4)]
            Speed = @(2100, 2300, 2500, 2700)[(Get-Random -Maximum 4)]
            Memory = @(65536, 131072, 262144, 524288)[(Get-Random -Maximum 4)]
            ESX_Version = "7.0.3"
            Build = "19193900"
            Cluster = "TestCluster-$([Math]::Ceiling($i / 2))"
            Datacenter = "TestDatacenter"
        }
    }
    return $hosts
}

function New-MockClusterData {
    <#
    .SYNOPSIS
        Generates mock cluster data
    #>
    param(
        [int]$ClusterCount = 2
    )
    
    $clusters = @()
    for ($i = 1; $i -le $ClusterCount; $i++) {
        $clusters += [PSCustomObject]@{
            Cluster = "TestCluster-$i"
            Datacenter = "TestDatacenter"
            VMs = (Get-Random -Minimum 10 -Maximum 30)
            Hosts = (Get-Random -Minimum 2 -Maximum 5)
            CPU_Total = (Get-Random -Minimum 48000 -Maximum 120000)
            Memory_Total = @(524288, 1048576, 2097152)[(Get-Random -Maximum 3)]
            HA_Enabled = $true
            DRS_Enabled = $true
            DRS_Automation = "fullyAutomated"
        }
    }
    return $clusters
}

function New-MockLicenseData {
    <#
    .SYNOPSIS
        Generates mock license data
    #>
    param()
    
    return @(
        [PSCustomObject]@{
            Product = "vSphere 7 Enterprise Plus"
            License_Key = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
            Used = 10
            Total = 25
            Host = "testvcenter01-esxi-1.contoso.local"
        },
        [PSCustomObject]@{
            Product = "vCenter Server 7 Standard"
            License_Key = "YYYYY-YYYYY-YYYYY-YYYYY-YYYYY"
            Used = 1
            Total = 1
            Host = "testvcenter01.contoso.local"
        }
    )
}

function New-MockMetaData {
    <#
    .SYNOPSIS
        Generates mock vMetaData
    #>
    param(
        [string]$VCenterName = "testvcenter01.contoso.local"
    )
    
    return @(
        [PSCustomObject]@{
            Property = "vCenter"
            Value = $VCenterName
        },
        [PSCustomObject]@{
            Property = "Export Date"
            Value = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        },
        [PSCustomObject]@{
            Property = "RVTools Version"
            Value = "4.5.0"
        },
        [PSCustomObject]@{
            Property = "Export User"
            Value = "administrator@vsphere.local"
        },
        [PSCustomObject]@{
            Property = "Total VMs"
            Value = "15"
        },
        [PSCustomObject]@{
            Property = "Total Hosts"
            Value = "3"
        }
    )
}

function Test-ExcelMerge {
    <#
    .SYNOPSIS
        Main test function for Excel merge functionality
    #>
    param(
        [string]$TestPath,
        [bool]$QuickMode = $false
    )
    
    Write-Host "🧪 Starting RVTools Excel Merge Test" -ForegroundColor Cyan
    Write-Host "📁 Test directory: $TestPath" -ForegroundColor Gray
    
    # Create test directory
    if (-not (Test-Path $TestPath)) {
        New-Item -Path $TestPath -ItemType Directory -Force | Out-Null
    }
    
    # Get tab definitions (use subset for quick test)
    $allTabs = Get-RVToolsTabDefinitions
    if ($QuickMode) {
        $tabsToTest = $allTabs | Select-Object -First 3
        Write-Host "🏃 Quick mode: Testing with $($tabsToTest.Count) tabs" -ForegroundColor Yellow
    } else {
        $tabsToTest = $allTabs
        Write-Host "🔍 Full test: Testing with $($tabsToTest.Count) tabs" -ForegroundColor Green
    }
    
    # Generate test files
    $testFiles = @()
    $vcenterName = "testvcenter01.contoso.local"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    Write-Host "📝 Generating mock Excel files..." -ForegroundColor Cyan
    
    foreach ($tab in $tabsToTest) {
        $fileName = "$vcenterName-$timestamp-$($tab.FileName).xlsx"
        $filePath = Join-Path $TestPath $fileName
        
        # Generate appropriate mock data based on tab type
        $mockData = switch ($tab.FileName) {
            'vInfo' { New-MockVMData -VMCount 15 -HostPrefix "testvcenter01" }
            'vHost' { New-MockHostData -HostCount 3 -HostPrefix "testvcenter01" }
            'vCluster' { New-MockClusterData -ClusterCount 2 }
            'vLicense' { New-MockLicenseData }
            'vCPU' { 
                # CPU data for VMs
                $vms = New-MockVMData -VMCount 15
                $vms | ForEach-Object { 
                    [PSCustomObject]@{
                        VM = $_.VM
                        CPUs = $_.Num_CPUs
                        Cores_per_Socket = 1
                        CPU_Usage_MHz = (Get-Random -Minimum 100 -Maximum 2000)
                        CPU_Usage_Percent = (Get-Random -Minimum 5 -Maximum 80)
                    }
                }
            }
            'vMemory' {
                # Memory data for VMs
                $vms = New-MockVMData -VMCount 15
                $vms | ForEach-Object {
                    [PSCustomObject]@{
                        VM = $_.VM
                        Memory_MB = $_.Memory
                        Memory_Usage_MB = [int]($_.Memory * (Get-Random -Minimum 30 -Maximum 90) / 100)
                        Memory_Usage_Percent = (Get-Random -Minimum 30 -Maximum 90)
                    }
                }
            }
            default { 
                # Generic data for other tabs
                1..5 | ForEach-Object {
                    [PSCustomObject]@{
                        Item = "TestItem$_"
                        Description = "Mock data for $($tab.FileName) tab"
                        Value = (Get-Random -Minimum 1 -Maximum 100)
                    }
                }
            }
        }
        
        # Create Excel file with both the tab data and vMetaData
        $excelParams = @{
            Path = $filePath
            WorksheetName = $tab.FileName
            AutoSize = $true
        }
        
        $mockData | Export-Excel @excelParams
        
        # Add vMetaData tab to each file (this simulates real RVTools behavior)
        $metaData = New-MockMetaData -VCenterName $vcenterName
        $metaData | Export-Excel -Path $filePath -WorksheetName "vMetaData" -AutoSize -Append
        
        $testFiles += $filePath
        Write-Host "  ✅ Created: $fileName" -ForegroundColor Green
    }
    
    Write-Host "📊 Generated $($testFiles.Count) test files" -ForegroundColor Green
    
    # Test the merge functionality
    Write-Host "🔗 Testing Excel merge functionality..." -ForegroundColor Cyan
    $mergedFile = Join-Path $TestPath "$vcenterName-$timestamp-MERGED.xlsx"
    
    $mergeResult = Merge-RVToolsExcelFiles -SourceFiles $testFiles -DestinationFile $mergedFile
    
    if ($mergeResult) {
        Write-Host "✅ Merge completed successfully!" -ForegroundColor Green
        
        # Validate the merged file
        Write-Host "🔍 Validating merged file..." -ForegroundColor Cyan
        
        if (Test-Path $mergedFile) {
            $worksheetInfo = Get-ExcelSheetInfo -Path $mergedFile
            Write-Host "📋 Merged file contains $($worksheetInfo.Count) worksheets:" -ForegroundColor Green
            
            foreach ($sheet in $worksheetInfo) {
                # Get actual row count by importing the sheet
                try {
                    $sheetData = Import-Excel -Path $mergedFile -WorksheetName $sheet.Name
                    $rowCount = if ($sheetData) { 
                        if ($sheetData.Count) { $sheetData.Count } else { 1 }
                    } else { 
                        0 
                    }
                    Write-Host "  📊 $($sheet.Name): $rowCount rows" -ForegroundColor Gray
                } catch {
                    Write-Host "  📊 $($sheet.Name): Unable to read sheet" -ForegroundColor Yellow
                }
            }
            
            # Check for vMetaData duplication
            $metaDataSheets = $worksheetInfo | Where-Object { $_.Name -eq 'vMetaData' }
            if ($metaDataSheets.Count -eq 1) {
                Write-Host "✅ vMetaData deduplication working correctly (1 vMetaData sheet)" -ForegroundColor Green
            } else {
                Write-Host "❌ vMetaData deduplication failed ($($metaDataSheets.Count) vMetaData sheets)" -ForegroundColor Red
                return $false
            }
            
            # Validate we have the expected number of data sheets
            $expectedDataSheets = $tabsToTest.Count
            $actualDataSheets = ($worksheetInfo | Where-Object { $_.Name -ne 'vMetaData' }).Count
            
            if ($actualDataSheets -eq $expectedDataSheets) {
                Write-Host "✅ All data sheets present ($actualDataSheets/$expectedDataSheets)" -ForegroundColor Green
            } else {
                Write-Host "❌ Missing data sheets ($actualDataSheets/$expectedDataSheets)" -ForegroundColor Red
                return $false
            }
            
        } else {
            Write-Host "❌ Merged file was not created" -ForegroundColor Red
            return $false
        }
        
    } else {
        Write-Host "❌ Merge failed!" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Main execution
try {
    Write-Host "🚀 RVTools Excel Merge Test Starting..." -ForegroundColor Magenta
    Write-Host "📅 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    
    $testResult = Test-ExcelMerge -TestPath $TestDataPath -QuickMode $QuickTest.IsPresent
    
    if ($testResult) {
        Write-Host ""
        Write-Host "🎉 ALL TESTS PASSED!" -ForegroundColor Green
        Write-Host "✅ Mock Excel files generated successfully" -ForegroundColor Green
        Write-Host "✅ Excel merge functionality working correctly" -ForegroundColor Green
        Write-Host "✅ vMetaData deduplication working" -ForegroundColor Green
        Write-Host "✅ All worksheets preserved in merge" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "❌ TESTS FAILED!" -ForegroundColor Red
        exit 1
    }
    
    # Cleanup or keep files
    if ($KeepTestFiles) {
        Write-Host ""
        Write-Host "📁 Test files preserved in: $TestDataPath" -ForegroundColor Yellow
        Write-Host "📋 You can manually inspect the Excel files:" -ForegroundColor Gray
        Get-ChildItem -Path $TestDataPath -Filter "*.xlsx" | ForEach-Object {
            Write-Host "  📄 $($_.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host ""
        Write-Host "🧹 Cleaning up test files..." -ForegroundColor Gray
        Remove-Item -Path $TestDataPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Cleanup completed" -ForegroundColor Green
    }
    
} catch {
    Write-Host ""
    Write-Host "💥 Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "🔍 Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    
    if (-not $KeepTestFiles) {
        Write-Host "🧹 Cleaning up test files..." -ForegroundColor Gray
        Remove-Item -Path $TestDataPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    exit 1
}

Write-Host ""
Write-Host "🏁 Test completed successfully!" -ForegroundColor Magenta
