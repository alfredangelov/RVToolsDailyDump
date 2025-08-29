@{
    Hosts = @(
        # You can list vCenter servers as plain strings (defaults to normal export mode):
        'vcenter01.contoso.local'
        'vcenter02.contoso.local'

        # Or as hashtables/objects if you need a different username per host:
        @{ Name = 'vcenter03.contoso.local'; Username = 'svc_rvtools@contoso.local' }
        @{ Name = 'vcenter04.contoso.local'; Username = 'admin@vsphere.local' }
        @{ Name = 'vcenter-prod.contoso.local'; Username = 'prod_service@contoso.local' }
        
        # Use ExportMode for hosts that need chunked export (large environments):
        @{ Name = 'vcenter-large.contoso.local'; Username = 'svc_rvtools@contoso.local'; ExportMode = 'Chunked' }
        @{ Name = 'vcenter-huge.contoso.local'; Username = 'admin@vsphere.local'; ExportMode = 'Chunked' }
        
        # You can mix all formats in the same list:
        'vcenter-dev.contoso.local'
        @{ Name = 'vcenter-dr.contoso.local'; Username = 'dr_admin@contoso.local'; ExportMode = 'Normal' }
    )
}
