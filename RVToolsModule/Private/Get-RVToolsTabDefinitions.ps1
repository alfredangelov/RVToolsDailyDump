function Get-RVToolsTabDefinitions {
    <#
    .SYNOPSIS
        Returns the standard RVTools tab definitions for chunked exports.

    .DESCRIPTION
        This function provides the standardized list of RVTools tabs with their
        command mappings and filenames for individual tab exports.

    .EXAMPLE
        $tabs = Get-RVToolsTabDefinitions

    .OUTPUTS
        System.Array - Array of hashtables containing Command and FileName properties.
    #>
    [CmdletBinding()]
    param()
    
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
