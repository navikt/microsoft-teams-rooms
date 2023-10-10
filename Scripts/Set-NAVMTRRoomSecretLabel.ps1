[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)] [String] $SubscriptionId ='93564b8e-ff1e-480e-9374-e6970f79ceb1',
    [Parameter(Mandatory = $false)] [String] $KeyVaultName = 'kv-mtr-accountsecret',
    [Parameter(Mandatory = $false)] [String] $FileName = "examples\mtrsecretlabels_example.csv"
)

# Liten sjekk på om vi er pålogget og har tilgang, hvis ikke logg på
if (-not (Get-AzContext -ListAvailable | Where-Object { $_.Subscription.Id -eq $SubscriptionId })) {
    Connect-AzAccount -SubscriptionId $SubscriptionId
}

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

$import = try {
    Import-Csv -Path $FileName -Delimiter ";" -Encoding utf8
}
catch {
    Write-Error "Unable to import csv file $FileName`: $($_.Exception.Message)"
}

Write-Verbose "Found $($import.Count) rooms in csv file $FileName"

$progress = 0

foreach($room in $import) {

    Write-Progress -Activity "Updating secret labels" -Status "Progress:" -PercentComplete ($progress / $import.Count * 100)

    $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $room.Name -ErrorAction SilentlyContinue

    if($null -eq $secret) {
        Write-Verbose "Secret $($room.Name) not found in keyvault $KeyVaultName"
        continue
    }

    $tags = [ordered]@{
        'RoomName' = $room.RoomName
        'Region' = $room.Region
        'Location' = $room.Location
    }

    Write-Verbose "Updating secret `"$($secret.Name)`" with tags: $($tags | ConvertTo-Json -Compress)"

    try {
        $null = $secret | Update-AzKeyVaultSecret -Tag $tags
    }
    catch {
        Write-Error "Unable to update secret $($secret.Name) in keyvault $KeyVaultName`: $($_.Exception.Message)"
    }

    $progress++

}

Write-Progress -Activity "Updating secret labels" -Status "Progress:" -Completed

Write-Host "Done!"