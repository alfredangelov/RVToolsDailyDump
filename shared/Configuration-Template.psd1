@{
    # Absolute or relative path to RVTools.exe
    RVToolsPath = 'C:\Program Files (x86)\Robware\RVTools\RVTools.exe'

    # Where to store exported Excel files (relative paths are resolved from the script directory)
    ExportFolder = 'export'

    # Where to store logs
    LogsFolder = 'log'

    # Optional: Additional arguments to pass to RVTools
    # E.g. list of tabs, omit some sheets, etc. Refer to RVTools CLI docs
    RVToolsArgs = @()

    # Logging configuration
    Logging = @{
        # Enable verbose/debug output
        EnableDebug = $false
        # Log level: 'INFO', 'WARN', 'ERROR', 'DEBUG'
        LogLevel = 'INFO'
    }

    # Authentication configuration using PowerShell SecretManagement
    Auth = @{
        # Method: 'SecretManagement' (recommended) or 'Prompt' (fallback)
        Method = 'SecretManagement'
        # Default vault for storing credentials
        DefaultVault = 'RVToolsVault'
        # Optional global default username; can be overridden per host in HostList.psd1
        Username = 'defaultAccount'
        # Secret name pattern: {HostName}-{Username} or custom pattern
        SecretNamePattern = '{HostName}-{Username}'
        # Use RVTools password encryption (recommended for security)
        UsePasswordEncryption = $true
    }

    # Email configuration (optional)
    Email = @{
        Enabled   = $false
        Method    = 'SMTP'  # Options: 'SMTP', 'MicrosoftGraph'
        From      = 'rvtools-reporter@example.com'
        To        = @('you@example.com')
        
        # SMTP Configuration (when Method = 'SMTP')
        SmtpServer= 'smtp.example.com'
        Port      = 25
        UseSsl    = $false
        
        # Microsoft Graph Configuration (when Method = 'MicrosoftGraph')
        TenantId     = 'your-tenant-id-guid'
        ClientId     = 'your-client-id-guid'
        ClientSecretName = 'MicrosoftGraph-ClientSecret'  # SecretManagement vault secret name
    }
}
