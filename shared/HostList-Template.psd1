@{
    Hosts = @(
        # You can list vCenter servers as plain strings:
        'vcenter01.contoso.local'
        'vcenter02.contoso.local'

        # Or as hashtables/objects if you need a different username per host:
        @{ Name = 'vcenter03.contoso.local'; Username = 'svc_rvtools@contoso.local' }
        @{ Name = 'vcenter04.contoso.local'; Username = 'admin@vsphere.local' }
        @{ Name = 'vcenter-prod.contoso.local'; Username = 'prod_service@contoso.local' }
        
        # You can mix both formats in the same list:
        'vcenter-dev.contoso.local'
        @{ Name = 'vcenter-dr.contoso.local'; Username = 'dr_admin@contoso.local' }
    )
}
