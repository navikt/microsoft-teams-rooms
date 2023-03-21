using namespace System.Net

param($Request, $TriggerMetadata)

# Dette er den eneste pålitelige måten jeg har funnet for å stoppe functionapp kode fra å fortsette på feil (?)
$global:erroractionpreference = 1

Import-Module -Name NAVHelpers
#. .\Solutions\MTR-TeamsWebhook\funcApp\Modules\NAVHelpers.psm1

$requestBody = $Request.Body | ConvertFrom-Json


# Hente app reg secrets (app settings og keyvault lages i bicep-koden)
$TenantId = ''
$AppId = ''
$ClientSecret = ''

$MsalToken = Get-TokenByAppSecret -appid $AppId -secret $ClientSecret -tenantID $TenantId


# Get a list of all MTR devices, and meeting room panels
$devices = @()

$graphRequest = Invoke-RestMethod -Headers @{Authorization = "Bearer $MsalToken" } -Method Get -Uri "https://graph.microsoft.com/beta/teamwork/devices?`$filter=deviceType eq 'teamsRoom' or deviceType eq 'teamsPanel'" #&select=id,healthStatus,createdDateTime,lastModifiedDateTime,hardwareDetail,currentUser"
$devices = $graphRequest.value

# Keep querying if the result has been paginated
while ($null -ne $graphRequest.'@odata.nextLink') {
  $graphRequest = Invoke-RestMethod -Headers @{Authorization = "Bearer $MsalToken" } -Method Get -Uri $graphRequest.'@odata.nextLink'
  $devices += $graphRequest.value
}


# health
$graphRequest = Invoke-RestMethod -Headers @{Authorization = "Bearer $MsalToken" } -Method Get -Uri "https://graph.microsoft.com/beta/teamwork/devices/$($devices[1].id)/health"

$graphRequest | ConvertTo-Json

$devices.Count
$hm = $devices | Select-Object -First 1 | ConvertTo-Json

$hm | ConvertTo-Csv
$hm | flatten-o

# panel
$graphRequest = Invoke-RestMethod -Headers @{Authorization = "Bearer $MsalToken" } -Method Get -Uri "https://graph.microsoft.com/beta/teamwork/devices?`$filter=deviceType eq 'teamsPanel'" #&select=id,healthStatus,createdDateTime,lastModifiedDateTime,hardwareDetail,currentUser"