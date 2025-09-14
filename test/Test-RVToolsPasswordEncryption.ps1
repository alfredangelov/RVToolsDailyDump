<#
.SYNOPSIS
    Test RVTools password encryption functionality.

.DESCRIPTION
    This script demonstrates and tests RVTools password encryption using the same
    method as the official RVToolsPasswordEncryption.ps1 script. It shows how
    passwords are encrypted and can be used to verify the encryption works.

.PARAMETER TestPassword
    Test password to encrypt. If not provided, prompts securely.
    Note: This is a test script parameter - in production use SecureString.

.PARAMETER ShowEncrypted
    Display the encrypted password (useful for testing).

.EXAMPLE
    .\Test-RVToolsPasswordEncryption.ps1

.EXAMPLE
    .\Test-RVToolsPasswordEncryption.ps1 -TestPassword "MyTestPassword123" -ShowEncrypted

.NOTES
    Uses Windows Data Protection API (DPAPI) - encrypted passwords only work
    for the same user account on the same computer where they were created.
#>

[CmdletBinding()]
param(
    # Using string for test convenience - in production, use SecureString
    [Parameter()] 
    [string] $TestPassword,
    
    [Parameter()] 
    [switch] $ShowEncrypted
)

Set-StrictMode -Version Latest

function Write-Log {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')] [string] $Level = 'INFO'
    )
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
}

function Get-RVToolsEncryptedPassword {
    param(
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential] $Credential
    )
    
    # Convert password to secure string and then to encrypted string using DPAPI
    $securePassword = $Credential.Password
    $encryptedPassword = $securePassword | ConvertFrom-SecureString
    
    # Add RVTools prefix so it knows this is an encrypted password
    return '_RVToolsV3PWD' + $encryptedPassword
}

function Test-PasswordDecryption {
    param(
        # This parameter contains DPAPI-encrypted data, not plaintext
        [Parameter(Mandatory)] 
        [string] $EncryptedPassword
    )
    
    try {
        # Remove the RVTools prefix
        $encryptedWithoutPrefix = $EncryptedPassword -replace '^_RVToolsV3PWD', ''
        
        # Convert back to SecureString
        $secureString = $encryptedWithoutPrefix | ConvertTo-SecureString
        
        # Convert to plain text for verification (normally RVTools would do this)
        $credential = New-Object System.Management.Automation.PSCredential("test", $secureString)
        $plainPassword = $credential.GetNetworkCredential().Password
        
        return $plainPassword
    }
    catch {
        Write-Log -Level 'ERROR' -Message "Failed to decrypt password: $($_.Exception.Message)"
        return $null
    }
}

Write-Log -Level 'INFO' -Message "RVTools Password Encryption Test"
Write-Log -Level 'INFO' -Message "================================"
Write-Log -Level 'INFO' -Message ""

# Get test credentials
if ($TestPassword) {
    $securePassword = $TestPassword | ConvertTo-SecureString -AsPlainText -Force
    $testCredential = New-Object System.Management.Automation.PSCredential("testuser", $securePassword)
    Write-Log -Level 'INFO' -Message "Using provided test password"
}
else {
    Write-Log -Level 'INFO' -Message "Please enter a test password for encryption:"
    $testCredential = Get-Credential -UserName "testuser" -Message "Enter test password"
}

# Encrypt the password
Write-Log -Level 'INFO' -Message "Encrypting password using RVTools method..."
$encryptedPassword = Get-RVToolsEncryptedPassword -Credential $testCredential

Write-Log -Level 'SUCCESS' -Message "Password encrypted successfully!"
Write-Log -Level 'INFO' -Message "Encrypted password length: $($encryptedPassword.Length) characters"
Write-Log -Level 'INFO' -Message "Starts with RVTools prefix: $(if ($encryptedPassword.StartsWith('_RVToolsV3PWD')) { 'Yes' } else { 'No' })"

if ($ShowEncrypted) {
    Write-Log -Level 'INFO' -Message "Encrypted password: $encryptedPassword"
}

# Test decryption to verify it works
Write-Log -Level 'INFO' -Message "Testing decryption..."
$decryptedPassword = Test-PasswordDecryption -EncryptedPassword $encryptedPassword

if ($decryptedPassword) {
    $originalPassword = $testCredential.GetNetworkCredential().Password
    if ($decryptedPassword -eq $originalPassword) {
        Write-Log -Level 'SUCCESS' -Message "Decryption test passed! Password matches original."
    }
    else {
        Write-Log -Level 'ERROR' -Message "Decryption test failed! Password does not match original."
    }
}
else {
    Write-Log -Level 'ERROR' -Message "Decryption test failed!"
}

Write-Log -Level 'INFO' -Message ""
Write-Log -Level 'INFO' -Message "Notes:"
Write-Log -Level 'INFO' -Message "- Encrypted passwords use Windows Data Protection API (DPAPI)"
Write-Log -Level 'INFO' -Message "- They only work for the same user on the same computer"
Write-Log -Level 'INFO' -Message "- RVTools recognizes the '_RVToolsV3PWD' prefix for encrypted passwords"
Write-Log -Level 'INFO' -Message "- This is more secure than passing plaintext passwords as arguments"
