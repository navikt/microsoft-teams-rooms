param($myTimer)

# This was the only reliable setting I found to stop code executing in Azure functions on errors (?)
$global:erroractionpreference = 1

# Retrieve secrets (set in bicep\functionApp.bicep)
$TenantId = $env:APPREG_TENANT
$AppId = $env:APPREG_APPID
$ClientSecret = $env:APPREG_CLIENTSECRET
$teamsHook = $env:TEAMSHOOK

# Function for retrieving Bearer token for Graph API requests
function Get-TokenByAppSecret {
    param ([string]$appID, $secret, $tenantID)
    
    # Initialize Graph token
    $tokenAuthURI = "https://login.microsoftonline.com/$tenantID/oauth2/token" # Common tokenAuthURI per tenant. Retrieved from Azure->App registrations->Endpoints->OAuth 2.0 Token Endpoint
    $requestBody = "grant_type=client_credentials&client_id=$appID&client_secret=$Secret&resource=https://graph.microsoft.com/"
    $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenAuthURI -body $requestBody -ContentType "application/x-www-form-urlencoded"
    $accesstoken = $tokenResponse.access_token # The actual token
    Write-Output $accesstoken
}

Write-Host "Attempting to retrieve a Bearer token..."

$MsalToken = Get-TokenByAppSecret -appid $AppId -secret $ClientSecret -tenantID $TenantId

if ($null -eq $MsalToken) { "Did not get a token, something went wrong..."; Exit 1 } else { "Token received!" }

[array]$MTRDevices = @()

$request = try {
    Write-Host "Fetching data via Graph API..."
    Invoke-RestMethod -Headers @{Authorization = "Bearer $MsalToken" } -Method Get -Uri "https://graph.microsoft.com/beta/teamwork/devices?`$filter=deviceType eq 'teamsRoom'&select=id,healthStatus,createdDateTime,lastModifiedDateTime,hardwareDetail,currentUser"
}
catch {
    Write-Error "$($_.Exception.Message)"
    Exit 1
}

$MTRDevices = $request.value

# Keep querying if the result has been paginated
while ($null -ne $request.'@odata.nextLink') {
    $request = Invoke-RestMethod -Headers @{Authorization = "Bearer $MsalToken" } -Method Get -Uri $request.'@odata.nextLink'
    $MTRDevices += $request.value
}

Write-Host "Retrieved a total of $($MTRDevices.Count) teamsRooms"

$MTRDevices | Add-Member -MemberType NoteProperty -Name "Online" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "Teams" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "Exchange" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "Intune" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "Compliance" -Value $null

$MTRDevices | Add-Member -MemberType NoteProperty -Name "PeripheralRoomCamera" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "PeripheralSpeaker" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "PeripheralConferenceSpeaker" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "PeripheralDisplay" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "PeripheralMicrophone" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "PeripheralHDMIingest" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "PeripheralContentCamera" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "PeripheralDisconnected" -Value $null

$MTRDevices | Add-Member -MemberType NoteProperty -Name "TeamsVersionStatus" -Value $null
$MTRDevices | Add-Member -MemberType NoteProperty -Name "TeamsVersion" -Value $null

$i = 0
foreach ($item in $MTRDevices) {
    $i++
    Write-Host "Fetching health related data for $i of $($MTRDevices.Count): $($item.currentUser.displayName)..."
    
    $health = Invoke-RestMethod -Headers @{Authorization = "Bearer $MsalToken" } -Method Get -Uri "https://graph.microsoft.com/beta/teamwork/devices/$($item.id)/health?`$select=id,connection,loginStatus,peripheralsHealth,softwareUpdateHealth,hardwareHealth"
    $item.Online = $health.connection.connectionStatus
    $item.Teams = $health.loginStatus.teamsConnection.connectionStatus
    $item.Exchange = $health.loginStatus.exchangeConnection.connectionStatus
    $item.PeripheralRoomCamera = $health.peripheralsHealth.roomCameraHealth.connection.connectionStatus
    $item.PeripheralSpeaker = $health.peripheralsHealth.speakerHealth.connection.connectionStatus
    $item.PeripheralConferenceSpeaker = $health.peripheralsHealth.communicationSpeakerHealth.connection.connectionStatus
    $item.PeripheralDisplay = $health.peripheralsHealth.displayHealthCollection.connection.connectionStatus
    $item.PeripheralMicrophone = $health.peripheralsHealth.microphoneHealth.connection.connectionStatus
    $item.PeripheralHDMIingest = $health.hardwareHealth.hdmiIngestHealth.connection.connectionStatus
    $item.PeripheralContentCamera = $health.peripheralsHealth.contentCameraHealth.connection.connectionStatus
    $item.TeamsVersionStatus = $health.softwareUpdateHealth.teamsClientSoftwareUpdateStatus.softwareFreshness
    $item.TeamsVersion = $health.softwareUpdateHealth.teamsClientSoftwareUpdateStatus.currentVersion
    Remove-Variable health
    
    # We want to check if it's enrolled and compliant in Intune as well
    Write-Host "Checking if devices are in Intune (MEM)..."

    # Let's simply match against serial numbers
    $MEM_SN = Invoke-RestMethod -Headers @{Authorization = "Bearer $MsalToken" } -Method Get -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=serialNumber eq '$($item.hardwareDetail.serialNumber)'"
    if ($null -ne $MEM_SN -AND $MEM_SN.'@odata.count' -gt 0) {
        $item.Intune = 'enrolled'
        $item.Compliance = $MEM_SN.value.complianceState
    }
    else {
        # If no matching serial number has been found (slow inventory?), let's compare against the SMTP name, as this is part of our naming standards
        $SMTP = Invoke-RestMethod -Headers @{Authorization = "Bearer $MsalToken" } -Method Get -Uri "https://graph.microsoft.com/beta/teamwork/devices/$($item.id)/configuration?`$select=teamsClientConfiguration"
        if ($null -ne $SMTP -AND $MEM_SN.'@odata.count' -gt 0) {
            $SMTP = (($SMTP.teamsClientConfiguration.accountConfiguration.onPremisesCalendarSyncConfiguration.smtpAddress) -split '@')[0]
            if ($null -ne $SMTP -AND $SMTP.StartsWith('MTR-')) {
                $MEM_SN = Invoke-RestMethod -Headers @{Authorization = "Bearer $MsalToken" } -Method Get -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$($SMTP)'"
                if ($null -ne $MEM_SN -AND $MEM_SN.'@odata.count' -gt 0) {
                    $item.Intune = 'unsure'
                    $item.Compliance = $MEM_SN.value.complianceState
                }
            }
        }
        Remove-Variable SMTP
    }
    Remove-Variable MEM_SN
}
# TODO: Sometimes there are duplicate results in the above query (due to re-enrollments for example)
# I should account for this somehow in the code, sorting by\keeping last sync date perhaps?
# Right now, when there are duplicates it will mess up the result a bit by doubling it up
# For example $item.Compliance could be set to something like "non-compliantcompliant"
# For now I fix this by deleting the old duplicate from Intune, since it shouldn't be there anyway :D

# Consolidates all disconnected peripherals into one column.
# (Peripheral health is not outputed at all at the moment)
foreach ($item in $MTRDevices) { 
    $item.PeripheralDisconnected = (
        ($item.psobject.Properties | ForEach-Object {
            if ($_.Name -like "Peripheral*" -AND $_.Value -contains "disconnected" ) { $_.Name -replace ".*Peripheral" }
        })
    ) -join ", "
}

Write-Host "Filtrerer på de vi ønsker å se..."

# Show absolutely all rooms marked as unhealthy (will usually include disconnected peripheral)
# $MTRDevices = $MTRDevices | Where-Object { $_.healthStatus -ne "healthy"}
#
# The above line would be much simpler to use, but today there are a lot of
# rooms that have peripheral issues at the moment, but without any practical implication.
# Since this generates a lot of noise, we'll not output everything until we've cleaned it up a bit.

#  Filter the devices to only show those with service-related issues
$MTRDevices = $MTRDevices | Where-Object { $_.Online -eq "disconnected" -OR $_.Teams -eq "disconnected" -OR $_.Exchange -eq "disconnected" -OR $_.Intune -ne "enrolled" -OR $_.Compliance -ne "compliant" }

# Sort the list so newest rooms are on top
# This is useful since Teams truncates messages a bit (you have to click "View more")
# and typically the newest rooms are the most intersting ones to pay attention to
$MTRDevices = $MTRDevices | Sort-Object -Descending -Property createdDateTime

# This is a bit messy for now... I'm creating a table, escaping some characters
# then unescaping later to fix emojis I want to use and... yeah... as I said it's messy
# There will be some Norwegian language used here since this is output for users :)
Write-Host "Generating HTML table..."
$tableOutput = $MTRDevices | Select-Object -property `
@{Label = "Møterom"; Expression = { "<a href=`"https://admin.teams.microsoft.com/devices/roomsystems/$($_.id)`" target=`"_blank`">$(if($null -eq $_.currentUser.displayName) { "Navn mangler" } else { $_.currentUser.displayName } )</a>" } }, `
    Online, Teams, Exchange, `
@{Label = "Intune"; Expression = { if ($_.Intune -ne "enrolled") { "notfound" } else { $_.Intune } } }, `
@{Label = "Compliance"; Expression = { if ($_.Compliance -eq 'compliant') { $_.Compliance } else { "noncompliant" } } }, `
@{Label = "Opprettet"; Expression = { $_.createdDateTime.ToShortDateString() } }

$tableOutput = $tableOutput | ConvertTo-Html -PreContent "<h1><b>Møterom som feiler på en eller flere helsesjekker:</b></h1><br />" #-PreContent "<h5>$header</h5>"

# Teams stuff
$tableOutput = $tableOutput -replace "<td>disconnected", "<td style=`"text-align: center;`">🔴"
$tableOutput = $tableOutput -replace "<td>connected", "<td style=`"text-align: center;`">🟢"

# Intune stuff
$tableOutput = $tableOutput -replace "<td>notfound", "<td style=`"text-align: center;`">🔴"
$tableOutput = $tableOutput -replace "<td>unsure", "<td style=`"text-align: center;`">🟠"
$tableOutput = $tableOutput -replace "<td>enrolled", "<td style=`"text-align: center;`">🟢"
$tableOutput = $tableOutput -replace "<td>noncompliant", "<td style=`"text-align: center;`">🔴"
$tableOutput = $tableOutput -replace "<td>compliant", "<td style=`"text-align: center;`">🟢"

# Sanitize everything to send with JSON later
$tableOutput = [System.Web.HttpUtility]::HtmlDecode($tableOutput) 

# Sanitation breaks some things, like Norwegian characters and emojis. 
# This is an annoying fix, and there's probably much better ways to do this...
# Laziness for now...
$tableOutput = $tableOutput.Replace('æ', [System.Web.HttpUtility]::HtmlEncode('æ'))
$tableOutput = $tableOutput.Replace('Æ', [System.Web.HttpUtility]::HtmlEncode('Æ'))
$tableOutput = $tableOutput.Replace('ø', [System.Web.HttpUtility]::HtmlEncode('ø'))
$tableOutput = $tableOutput.Replace('Ø', [System.Web.HttpUtility]::HtmlEncode('Ø'))
$tableOutput = $tableOutput.Replace('å', [System.Web.HttpUtility]::HtmlEncode('å'))
$tableOutput = $tableOutput.Replace('Å', [System.Web.HttpUtility]::HtmlEncode('Å'))
$tableOutput = $tableOutput.Replace('🔴', [System.Web.HttpUtility]::HtmlEncode('🔴'))
$tableOutput = $tableOutput.Replace('🟠', [System.Web.HttpUtility]::HtmlEncode('🟠'))
$tableOutput = $tableOutput.Replace('🟢', [System.Web.HttpUtility]::HtmlEncode('🟢'))

# output the table locally for debugging
#$tableOutput | Out-File c:\temp\mtrstatus.htm
#& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" c:\temp\mtrstatus.htm

Write-Host "Sending table to Teams..."

$body = "{`"text`":$($tableOutput | ConvertTo-Json -Compress)}"
Invoke-RestMethod -Uri $teamsHook -Method Post -Body $body -ContentType 'application/json'

Write-Host "Done :)"