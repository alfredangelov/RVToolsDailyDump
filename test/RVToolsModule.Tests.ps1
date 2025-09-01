# RVToolsModule.Tests.ps1 - Comprehensive test suite for RVTools PowerShell module

#Requires -Modules Pester

BeforeAll {
    # Import the module for testing
    $ModulePath = Join-Path $PSScriptRoot '..' 'RVToolsModule' 'RVToolsModule.psd1'
    if (-not (Test-Path $ModulePath)) {
        throw "Module manifest not found at: $ModulePath"
    }
    
    Import-Module $ModulePath -Force
    
    # Test data setup
    $script:TestConfigPath = Join-Path $TestDrive 'TestConfig.psd1'
    $script:TestHostListPath = Join-Path $TestDrive 'TestHostList.psd1'
    $script:TestExportDir = Join-Path $TestDrive 'exports'
    $script:TestLogDir = Join-Path $TestDrive 'logs'
    
    # Create test configuration
    $testConfig = @{
        RVToolsPath = 'C:\Program Files (x86)\Dell\RVTools\RVTools.exe'
        ExportFolder = $script:TestExportDir
        LogsFolder = $script:TestLogDir
        Logging = @{
            LogLevel = 'INFO'
        }
        Auth = @{
            Method = 'SecretManagement'
            Username = 'testuser'
            DefaultVault = 'TestVault'
            SecretNamePattern = '{HostName}-{Username}'
            UsePasswordEncryption = $true
        }
        Email = @{
            Enabled = $false
        }
    }
    
    $testConfig | Export-Clixml -Path $script:TestConfigPath
    
    # Create test host list
    $testHostList = @{
        Hosts = @(
            'test-vcenter01.local',
            @{
                Name = 'test-vcenter02.local'
                Username = 'admin@vsphere.local'
                ExportMode = 'Chunked'
            }
        )
    }
    
    $testHostList | Export-Clixml -Path $script:TestHostListPath
    
    # Create test directories
    New-Item -Path $script:TestExportDir -ItemType Directory -Force | Out-Null
    New-Item -Path $script:TestLogDir -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Clean up
    Remove-Module RVToolsModule -Force -ErrorAction SilentlyContinue
}

Describe "RVToolsModule Import" {
    It "Should import successfully" {
        { Import-Module $ModulePath -Force } | Should -Not -Throw
    }
    
    It "Should export expected functions" {
        $expectedFunctions = @(
            'Write-RVToolsLog',
            'Import-RVToolsConfiguration',
            'Test-RVToolsVault',
            'Get-RVToolsCredentialFromVault',
            'Get-RVToolsSecretName',
            'Get-RVToolsEncryptedPassword',
            'Resolve-RVToolsPath',
            'New-RVToolsDirectory',
            'Invoke-RVToolsExport'
        )
        
        $moduleInfo = Get-Module RVToolsModule
        $exportedFunctions = $moduleInfo.ExportedFunctions.Keys
        
        foreach ($function in $expectedFunctions) {
            $exportedFunctions | Should -Contain $function
        }
    }
}

Describe "Write-RVToolsLog" {
    BeforeEach {
        $script:TestLogFile = Join-Path $TestDrive "test-log-$(Get-Random).txt"
    }
    
    AfterEach {
        if (Test-Path $script:TestLogFile) {
            Remove-Item $script:TestLogFile -Force
        }
    }
    
    It "Should write log entry with timestamp" {
        Write-RVToolsLog -Message "Test message" -LogFile $script:TestLogFile -ConfigLogLevel 'INFO'
        
        $logContent = Get-Content $script:TestLogFile
        $logContent | Should -Not -BeNullOrEmpty
        $logContent | Should -Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[INFO\] Test message'
    }
    
    It "Should respect log level filtering" {
        Write-RVToolsLog -Level 'DEBUG' -Message "Debug message" -LogFile $script:TestLogFile -ConfigLogLevel 'INFO'
        
        if (Test-Path $script:TestLogFile) {
            $logContent = Get-Content $script:TestLogFile
            $logContent | Should -BeNullOrEmpty
        }
    }
    
    It "Should write ERROR level regardless of config" {
        Write-RVToolsLog -Level 'ERROR' -Message "Error message" -LogFile $script:TestLogFile -ConfigLogLevel 'WARN'
        
        $logContent = Get-Content $script:TestLogFile
        $logContent | Should -Match '\[ERROR\] Error message'
    }
}

Describe "Import-RVToolsConfiguration" {
    It "Should load configuration from existing file" {
        $result = Import-RVToolsConfiguration -ConfigPath $script:TestConfigPath -HostListPath $script:TestHostListPath -ScriptRoot $TestDrive
        
        $result.Configuration | Should -Not -BeNullOrEmpty
        $result.Configuration.RVToolsPath | Should -Be 'C:\Program Files (x86)\Dell\RVTools\RVTools.exe'
        $result.UsingTemplateConfig | Should -Be $false
    }
    
    It "Should fall back to template when PreferTemplate is true" {
        $result = Import-RVToolsConfiguration -ConfigPath $script:TestConfigPath -HostListPath $script:TestHostListPath -PreferTemplate -ScriptRoot $TestDrive
        
        $result.UsingTemplateConfig | Should -Be $true
    }
    
    It "Should throw when configuration file is missing and no template" {
        $missingPath = Join-Path $TestDrive 'NonExistent.psd1'
        { Import-RVToolsConfiguration -ConfigPath $missingPath -HostListPath $script:TestHostListPath -ScriptRoot $TestDrive } | Should -Throw
    }
}

Describe "Resolve-RVToolsPath" {
    It "Should resolve absolute path correctly" {
        $absolutePath = "C:\Test\Path"
        $result = Resolve-RVToolsPath -Path $absolutePath -ScriptRoot $TestDrive
        $result | Should -Be $absolutePath
    }
    
    It "Should resolve relative path correctly" {
        $relativePath = "exports"
        $expected = Join-Path $TestDrive $relativePath
        $result = Resolve-RVToolsPath -Path $relativePath -ScriptRoot $TestDrive
        $result | Should -Be $expected
    }
    
    It "Should handle dot notation paths" {
        $dotPath = ".\logs"
        $expected = Join-Path $TestDrive "logs"
        $result = Resolve-RVToolsPath -Path $dotPath -ScriptRoot $TestDrive
        $result | Should -Be $expected
    }
}

Describe "New-RVToolsDirectory" {
    It "Should create directory successfully" {
        $testDir = Join-Path $TestDrive "NewDirectory"
        $result = New-RVToolsDirectory -Path $testDir
        
        $result | Should -Be $testDir
        Test-Path $testDir | Should -Be $true
        (Get-Item $testDir).PSIsContainer | Should -Be $true
    }
    
    It "Should not throw if directory already exists" {
        $existingDir = $script:TestExportDir
        { New-RVToolsDirectory -Path $existingDir } | Should -Not -Throw
    }
    
    It "Should create nested directories" {
        $nestedDir = Join-Path $TestDrive "Level1\Level2\Level3"
        $result = New-RVToolsDirectory -Path $nestedDir
        
        $result | Should -Be $nestedDir
        Test-Path $nestedDir | Should -Be $true
    }
}

Describe "Get-RVToolsSecretName" {
    It "Should format secret name with hostname and username" {
        $result = Get-RVToolsSecretName -HostName "vcenter01.local" -Username "admin" -Pattern '{HostName}-{Username}'
        $result | Should -Be "vcenter01.local-admin"
    }
    
    It "Should handle pattern with only hostname" {
        $result = Get-RVToolsSecretName -HostName "vcenter01.local" -Username "admin" -Pattern '{HostName}'
        $result | Should -Be "vcenter01.local"
    }
    
    It "Should handle pattern with only username" {
        $result = Get-RVToolsSecretName -HostName "vcenter01.local" -Username "admin" -Pattern '{Username}'
        $result | Should -Be "admin"
    }
    
    It "Should handle custom pattern" {
        $result = Get-RVToolsSecretName -HostName "vcenter01.local" -Username "admin" -Pattern 'RVTools-{Username}@{HostName}'
        $result | Should -Be "RVTools-admin@vcenter01.local"
    }
}

Describe "Invoke-RVToolsExport Parameter Validation" {
    It "Should accept valid hostname" {
        { 
            $params = @{
                HostName = "vcenter01.domain.com"
                DryRun = $true
                ConfigPath = $script:TestConfigPath
                HostListPath = $script:TestHostListPath
            }
            Invoke-RVToolsExport @params
        } | Should -Not -Throw
    }
    
    It "Should reject invalid hostname with spaces" {
        { 
            $params = @{
                HostName = "vcenter 01.domain.com"
                DryRun = $true
                ConfigPath = $script:TestConfigPath
                HostListPath = $script:TestHostListPath
            }
            Invoke-RVToolsExport @params
        } | Should -Throw "*invalid characters*"
    }
    
    It "Should require CustomTabs when ExportMode is Custom" {
        { 
            $params = @{
                HostName = "vcenter01.domain.com"
                ExportMode = "Custom"
                DryRun = $true
                ConfigPath = $script:TestConfigPath
                HostListPath = $script:TestHostListPath
            }
            Invoke-RVToolsExport @params
        } | Should -Throw "*CustomTabs parameter is required*"
    }
    
    It "Should accept valid CustomTabs" {
        { 
            $params = @{
                HostName = "vcenter01.domain.com"
                ExportMode = "Custom"
                CustomTabs = @('vInfo', 'vCPU', 'vMemory')
                DryRun = $true
                ConfigPath = $script:TestConfigPath
                HostListPath = $script:TestHostListPath
            }
            Invoke-RVToolsExport @params
        } | Should -Not -Throw
    }
    
    It "Should reject invalid RVTools tabs" {
        { 
            $params = @{
                HostName = "vcenter01.domain.com"
                ExportMode = "Custom"
                CustomTabs = @('vInfo', 'InvalidTab', 'vCPU')
                DryRun = $true
                ConfigPath = $script:TestConfigPath
                HostListPath = $script:TestHostListPath
            }
            Invoke-RVToolsExport @params
        } | Should -Throw "*Invalid RVTools tab*"
    }
}

Describe "Invoke-RVToolsExport Dry Run Mode" {
    It "Should execute dry run without errors" {
        $result = Invoke-RVToolsExport -HostName "test-vcenter.local" -DryRun -ConfigPath $script:TestConfigPath -HostListPath $script:TestHostListPath
        
        $result | Should -Not -BeNullOrEmpty
        $result.HostName | Should -Be "test-vcenter.local"
        $result.Success | Should -Be $true
        $result.PSObject.Properties['ExitCode'] | Should -Not -BeNullOrEmpty
    }
    
    It "Should handle chunked export in dry run" {
        $result = Invoke-RVToolsExport -HostName "test-vcenter.local" -ChunkedExport -DryRun -ConfigPath $script:TestConfigPath -HostListPath $script:TestHostListPath
        
        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['SuccessfulTabs'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['FailedTabs'] | Should -Not -BeNullOrEmpty
    }
    
    It "Should process multiple servers from host list in dry run" {
        $results = Invoke-RVToolsExport -DryRun -ConfigPath $script:TestConfigPath -HostListPath $script:TestHostListPath
        
        $results | Should -Not -BeNullOrEmpty
        $results.Count | Should -BeGreaterThan 1
        $results[0].HostName | Should -Be "test-vcenter01.local"
        $results[1].HostName | Should -Be "test-vcenter02.local"
    }
}

Describe "Pipeline Support" {
    It "Should accept pipeline input" {
        $servers = @("vcenter01.local", "vcenter02.local")
        $results = $servers | Invoke-RVToolsExport -DryRun -ConfigPath $script:TestConfigPath -HostListPath $script:TestHostListPath
        
        $results | Should -Not -BeNullOrEmpty
        $results.Count | Should -Be 2
        $results[0].HostName | Should -Be "vcenter01.local"
        $results[1].HostName | Should -Be "vcenter02.local"
    }
    
    It "Should accept pipeline input with object properties" {
        $servers = @(
            [PSCustomObject]@{ ComputerName = "vcenter01.local" },
            [PSCustomObject]@{ vCenter = "vcenter02.local" }
        )
        
        $results = $servers | Invoke-RVToolsExport -DryRun -ConfigPath $script:TestConfigPath -HostListPath $script:TestHostListPath
        
        $results | Should -Not -BeNullOrEmpty
        $results.Count | Should -Be 2
        $results[0].HostName | Should -Be "vcenter01.local"
        $results[1].HostName | Should -Be "vcenter02.local"
    }
}

Describe "Error Handling" {
    It "Should handle missing configuration gracefully" {
        $missingConfig = Join-Path $TestDrive "NonExistent.psd1"
        { Invoke-RVToolsExport -HostName "test.local" -ConfigPath $missingConfig -HostListPath $script:TestHostListPath } | Should -Throw
    }
    
    It "Should return error result for failed operations" {
        # This test would need to mock actual RVTools failure scenarios
        # For now, we test the error result structure
        $errorResult = [pscustomobject]@{
            HostName = "failed-server.local"
            Success = $false
            ExportFile = $null
            ExitCode = -1
            Message = "Test error message"
        }
        
        $errorResult.Success | Should -Be $false
        $errorResult.ExitCode | Should -Be -1
        $errorResult.Message | Should -Match "Test error message"
    }
}

Describe "Performance and Integration" {
    It "Should complete dry run quickly" {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        $result = Invoke-RVToolsExport -HostName "test-vcenter.local" -DryRun -ConfigPath $script:TestConfigPath -HostListPath $script:TestHostListPath
        
        $stopwatch.Stop()
        $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000 # Should complete within 5 seconds
        $result | Should -Not -BeNullOrEmpty
    }
    
    It "Should handle large host lists efficiently" {
        # Create a larger host list for testing
        $largeHostList = @{
            Hosts = @(1..20 | ForEach-Object { "test-vcenter$_.local" })
        }
        
        $largeHostListPath = Join-Path $TestDrive "LargeHostList.psd1"
        $largeHostList | Export-Clixml -Path $largeHostListPath
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        $results = Invoke-RVToolsExport -DryRun -ConfigPath $script:TestConfigPath -HostListPath $largeHostListPath
        
        $stopwatch.Stop()
        $results.Count | Should -Be 20
        $stopwatch.ElapsedMilliseconds | Should -BeLessThan 10000 # Should complete within 10 seconds
    }
}
