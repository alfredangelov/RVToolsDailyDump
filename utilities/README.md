# RVTools Utilities

This folder contains utility scripts for maintaining and troubleshooting the RVTools environment.

## Fix-RVToolsLog4NetConfig.ps1

**Purpose:** Fixes the log4net configuration issue in RVTools where the main config file declares a log4net section but doesn't include the actual configuration.

**When to use:**

- After installing or updating RVTools
- When encountering log4net errors like: "Failed to find configuration section 'log4net' in the application's .config file"
- When RVTools command-line operations fail with configuration-related errors

**Requirements:**

- Must be run as Administrator (modifies files in Program Files)
- RVTools must be installed in the standard location: `C:\Program Files (x86)\Dell\RVTools\`

**Usage:**

```powershell
# Run PowerShell as Administrator, then:
cd "C:\Path\To\RVToolsDailyDump\utilities"
.\Fix-RVToolsLog4NetConfig.ps1
```

**What it does:**

1. Creates a backup of the original `RVTools.exe.config`
2. Reads the existing log4net configuration from `log4net.config`
3. Merges the log4net section into the main configuration file
4. Validates the resulting configuration

**Files modified:**

- `C:\Program Files (x86)\Dell\RVTools\RVTools.exe.config` (main config)
- `C:\Program Files (x86)\Dell\RVTools\RVTools.exe.config.backup` (backup created)

**Note:** This fix was applied on 2025-08-30 and resolved connection issues with RVTools version 4.7.1.4. Keep this utility for future RVTools updates that might reintroduce the configuration issue.
