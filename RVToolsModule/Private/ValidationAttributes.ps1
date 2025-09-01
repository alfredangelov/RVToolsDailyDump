# Custom validation classes for RVTools module

# Validates that a hostname is valid (not just IP validation, but reasonable hostname format)
class ValidateHostNameAttribute : System.Management.Automation.ValidateArgumentsAttribute {
    [void]Validate([object]$arguments, [System.Management.Automation.EngineIntrinsics]$engineIntrinsics) {
        if ([string]::IsNullOrWhiteSpace($arguments)) {
            throw [System.ArgumentException]::new("Hostname cannot be null or empty.")
        }
        
        $hostname = [string]$arguments
        
        # Basic hostname validation
        if ($hostname.Length -gt 253) {
            throw [System.ArgumentException]::new("Hostname cannot exceed 253 characters.")
        }
        
        # Check for invalid characters
        if ($hostname -match '[^a-zA-Z0-9\.\-]') {
            throw [System.ArgumentException]::new("Hostname contains invalid characters. Only letters, numbers, dots, and hyphens are allowed.")
        }
        
        # Check that it doesn't start or end with a hyphen or dot
        if ($hostname -match '^[\.\-]' -or $hostname -match '[\.\-]$') {
            throw [System.ArgumentException]::new("Hostname cannot start or end with a dot or hyphen.")
        }
        
        # Check for consecutive dots
        if ($hostname -match '\.\.') {
            throw [System.ArgumentException]::new("Hostname cannot contain consecutive dots.")
        }
    }
}

# Validates that a file path exists and is accessible
class ValidateFileExistsAttribute : System.Management.Automation.ValidateArgumentsAttribute {
    [void]Validate([object]$arguments, [System.Management.Automation.EngineIntrinsics]$engineIntrinsics) {
        if ([string]::IsNullOrWhiteSpace($arguments)) {
            return # Allow empty paths for optional parameters
        }
        
        $path = [string]$arguments
        
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw [System.ArgumentException]::new("File not found: '$path'")
        }
        
        try {
            # Test if we can read the file
            $null = Get-Content -LiteralPath $path -TotalCount 1 -ErrorAction Stop
        } catch {
            throw [System.ArgumentException]::new("File exists but is not readable: '$path'. Error: $($_.Exception.Message)")
        }
    }
}

# Validates that a directory exists and is accessible
class ValidateDirectoryExistsAttribute : System.Management.Automation.ValidateArgumentsAttribute {
    [void]Validate([object]$arguments, [System.Management.Automation.EngineIntrinsics]$engineIntrinsics) {
        if ([string]::IsNullOrWhiteSpace($arguments)) {
            return # Allow empty paths for optional parameters
        }
        
        $path = [string]$arguments
        
        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            throw [System.ArgumentException]::new("Directory not found: '$path'")
        }
        
        try {
            # Test if we can access the directory
            $null = Get-ChildItem -LiteralPath $path -Force -ErrorAction Stop | Select-Object -First 1
        } catch [System.UnauthorizedAccessException] {
            throw [System.ArgumentException]::new("Directory exists but is not accessible: '$path'. Check permissions.")
        } catch {
            # Other errors might be OK (like empty directory)
        }
    }
}

# Validates that RVTools tabs are valid
class ValidateRVToolsTabsAttribute : System.Management.Automation.ValidateArgumentsAttribute {
    static [string[]] $ValidTabs = @(
        'vInfo', 'vCPU', 'vMemory', 'vDisk', 'vPartition', 'vNetwork', 'vUSB', 'vCD',
        'vSnapshot', 'vTools', 'vSource', 'vRP', 'vCluster', 'vHost', 'vHBA', 'vNIC', 
        'vSwitch', 'vPort', 'dvSwitch', 'dvPort', 'vSC+VMK', 'vDatastore', 'vMultiPath', 
        'vLicense', 'vFileInfo', 'vHealth'
    )
    
    [void]Validate([object]$arguments, [System.Management.Automation.EngineIntrinsics]$engineIntrinsics) {
        if ($null -eq $arguments) {
            return # Allow null for optional parameters
        }
        
        $tabs = @($arguments)
        
        foreach ($tab in $tabs) {
            if ($tab -notin [ValidateRVToolsTabsAttribute]::ValidTabs) {
                $validTabsList = [ValidateRVToolsTabsAttribute]::ValidTabs -join ', '
                throw [System.ArgumentException]::new("Invalid RVTools tab: '$tab'. Valid tabs are: $validTabsList")
            }
        }
        
        # Check for duplicates
        $uniqueTabs = $tabs | Select-Object -Unique
        if ($uniqueTabs.Count -ne $tabs.Count) {
            throw [System.ArgumentException]::new("Duplicate tabs found in the list. Each tab should only be specified once.")
        }
    }
}

# Validates username format (basic validation for common patterns)
class ValidateUsernameAttribute : System.Management.Automation.ValidateArgumentsAttribute {
    [void]Validate([object]$arguments, [System.Management.Automation.EngineIntrinsics]$engineIntrinsics) {
        if ([string]::IsNullOrWhiteSpace($arguments)) {
            return # Allow empty for optional parameters
        }
        
        $username = [string]$arguments
        
        # Basic username validation
        if ($username.Length -gt 104) { # Common max length for usernames
            throw [System.ArgumentException]::new("Username cannot exceed 104 characters.")
        }
        
        # Check for obvious invalid characters (very permissive, just catching obvious mistakes)
        if ($username -match '[\s\r\n\t]') {
            throw [System.ArgumentException]::new("Username cannot contain whitespace characters.")
        }
        
        if ($username -match '^[\.\-]' -or $username -match '[\.\-]$') {
            throw [System.ArgumentException]::new("Username cannot start or end with a dot or hyphen.")
        }
    }
}
