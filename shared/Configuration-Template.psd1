@{
	# Absolute or relative path to RVTools.exe
	RVToolsPath = 'C:\Program Files (x86)\Robware\RVTools\RVTools.exe'

	# Where to store exported Excel files (relative paths are resolved from the script directory)
	ExportFolder = 'exports'

	# Where to store logs
	LogsFolder = 'logs'

	# Optional: Additional arguments to pass to RVTools
	# E.g. list of tabs, omit some sheets, etc. Refer to RVTools CLI docs
	RVToolsArgs = @()

	# Authentication configuration
	Auth = @{
		# Method can be 'Prompt' (ask for username/password) or 'Preset' (use username below)
		Method   = 'Prompt'
		Username = '' # Optional global default; can be overridden per host in HostList.psd1
	}

	# Email configuration (optional)
	Email = @{
		Enabled   = $false
		From      = 'rvtools-reporter@example.com'
		To        = @('you@example.com')
		SmtpServer= 'smtp.example.com'
		Port      = 25
		UseSsl    = $false
	}
}
