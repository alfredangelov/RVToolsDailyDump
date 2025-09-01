function Get-RVToolsEncryptedPassword {
    <#
    .SYNOPSIS
        Encrypts passwords for RVTools using DPAPI encryption.

    .DESCRIPTION
        This function converts PSCredential passwords to RVTools-compatible
        encrypted format using Windows DPAPI (Data Protection API).

    .PARAMETER Credential
        The PSCredential object containing the password to encrypt.

    .EXAMPLE
        $encryptedPassword = Get-RVToolsEncryptedPassword -Credential $cred

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    # Convert password to secure string and then to encrypted string using DPAPI
    $securePassword = $Credential.Password
    $encryptedPassword = $securePassword | ConvertFrom-SecureString
    
    # Add RVTools prefix so it knows this is an encrypted password
    return '_RVToolsV3PWD' + $encryptedPassword
}
