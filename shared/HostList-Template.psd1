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
