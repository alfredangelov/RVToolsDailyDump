function Send-RVToolsGraphEmail {
    <#
    .SYNOPSIS
        Sends email using Microsoft Graph API for RVTools reports.

    .DESCRIPTION
        This function sends email notifications using Microsoft Graph with secure
        credential management for RVTools daily reports.

    .PARAMETER TenantId
        Azure AD Tenant ID.

    .PARAMETER ClientId
        Azure AD Application Client ID.

    .PARAMETER ClientSecret
        Client secret (if provided directly).

    .PARAMETER ClientSecretName
        Name of the client secret stored in SecretManagement vault.

    .PARAMETER VaultName
        Name of the SecretManagement vault containing the client secret.

    .PARAMETER From
        Sender email address.

    .PARAMETER To
        Array of recipient email addresses.

    .PARAMETER Subject
        Email subject line.

    .PARAMETER Body
        Email body content.

    .EXAMPLE
        Send-RVToolsGraphEmail -TenantId "tenant-id" -ClientId "client-id" -ClientSecretName "Graph-Secret" -From "sender@domain.com" -To @("recipient@domain.com") -Subject "Report" -Body "Content"

    .OUTPUTS
        System.Boolean - Returns $true if email was sent successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,
        
        [Parameter(Mandatory)]
        [string]$ClientId,
        
        [Parameter()]
        [string]$ClientSecret,
        
        [Parameter()]
        [string]$ClientSecretName,
        
        [Parameter()]
        [string]$VaultName = 'RVToolsVault',
        
        [Parameter(Mandatory)]
        [string]$From,
        
        [Parameter(Mandatory)]
        [string[]]$To,
        
        [Parameter(Mandatory)]
        [string]$Subject,
        
        [Parameter(Mandatory)]
        [string]$Body
    )
    
    try {
        # Resolve ClientSecret from vault if ClientSecretName is provided
        if ($ClientSecretName -and -not $ClientSecret) {
            try {
                $ClientSecret = Get-Secret -Name $ClientSecretName -Vault $VaultName -AsPlainText -ErrorAction Stop
                Write-RVToolsLog -Message "Retrieved ClientSecret from vault: $ClientSecretName" -Level 'DEBUG'
            } catch {
                Write-RVToolsLog -Message "Failed to retrieve ClientSecret from vault '$VaultName' with name '$ClientSecretName': $($_.Exception.Message)" -Level 'ERROR'
                return $false
            }
        }
        
        # Validate that we have a ClientSecret
        if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
            Write-RVToolsLog -Message "ClientSecret is required but not provided or retrieved from vault" -Level 'ERROR'
            return $false
        }
        
        # Import required modules
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        Import-Module Microsoft.Graph.Mail -ErrorAction Stop
        
        # Create client secret credential
        $SecureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $ClientSecretCredential = New-Object System.Management.Automation.PSCredential($ClientId, $SecureSecret)
        
        # Connect to Microsoft Graph
        Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -NoWelcome
        
        # Create the email message
        $BodyObject = @{
            ContentType = "Text"
            Content = $Body
        }
        
        $ToRecipients = @()
        foreach ($recipient in $To) {
            $ToRecipients += @{
                EmailAddress = @{
                    Address = $recipient
                }
            }
        }
        
        $Message = @{
            Subject = $Subject
            Body = $BodyObject
            ToRecipients = $ToRecipients
        }
        
        # Send the email
        Send-MgUserMail -UserId $From -Message $Message
        
        # Disconnect from Microsoft Graph
        Disconnect-MgGraph | Out-Null
        
        Write-RVToolsLog -Message "Successfully sent Microsoft Graph email to $($To -join ', ')" -Level 'SUCCESS'
        return $true
        
    } catch {
        Write-RVToolsLog -Message "Microsoft Graph email error: $($_.Exception.Message)" -Level 'ERROR'
        try { Disconnect-MgGraph | Out-Null } catch { }
        return $false
    }
}
