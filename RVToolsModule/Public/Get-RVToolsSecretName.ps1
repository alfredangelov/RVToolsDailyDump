function Get-RVToolsSecretName {
    <#
    .SYNOPSIS
        Generates secret names for RVTools credentials based on hostname and username.

    .DESCRIPTION
        This function creates consistent secret names for storing credentials in
        SecretManagement vaults using configurable patterns.

    .PARAMETER HostName
        The vCenter hostname.

    .PARAMETER Username
        The username for the credential.

    .PARAMETER Pattern
        The pattern for generating secret names. Use {HostName} and {Username} placeholders.

    .EXAMPLE
        Get-RVToolsSecretName -HostName "vcenter01.local" -Username "admin" -Pattern "{HostName}-{Username}"

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HostName,
        
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter()]
        [string]$Pattern = '{HostName}-{Username}'
    )
    
    return $Pattern -replace '\{HostName\}', $HostName -replace '\{Username\}', $Username
}
