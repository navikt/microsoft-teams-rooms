<#
.SYNOPSIS
This module provides a set of helper functions for common tasks in PowerShell.

.DESCRIPTION
This module contains functions that can be used to perform various tasks such as logging in to Graph API etc.

.AUTHORS
kenneth.sundby@nav.no

.VERSION
v1.0.0 - Initial release

.CHANGELOG
v1.0.0 - Initial release

.EXAMPLE
Example usage of this module could be:
Import-Module NAVHelpers
Get-TokenByAppSecret -AppID <id> -Secret <secret> -TenantID <tenantid>

.NOTES
This module is intended for use by users with basic PowerShell knowledge. 
#>

function Get-TokenByAppSecret {
    param (
        [Parameter(Mandatory = $true)] [System.Guid]  $AppID,
        [Parameter(Mandatory = $true)] [String]       $Secret,
        [Parameter(Mandatory = $true)] [System.Guid]  $TenantID
    )

    $tokenAuthURI = "https://login.microsoftonline.com/$tenantID/oauth2/token"
    $tokenRequestBody = "grant_type=client_credentials&client_id=$appID&client_secret=$Secret&resource=https://graph.microsoft.com/"
    $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenAuthURI -Body $tokenRequestBody -ContentType "application/x-www-form-urlencoded"

    if ([String]::IsNullOrEmpty($tokenResponse.access_token)) {
        Throw "Could not retrieve token, something went wrong."
    }

    Write-Debug "Received token."

    return $tokenResponse.access_token
}