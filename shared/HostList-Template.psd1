@(
	# You can list vCenter servers as plain strings:
	'vcenter01.contoso.local'
	'vcenter02.contoso.local'

	# Or as hashtables/objects if you need a different username per host:
	@{ Name = 'vcenter03.contoso.local'; Username = 'svc_rvtools@contoso.local' }
)
