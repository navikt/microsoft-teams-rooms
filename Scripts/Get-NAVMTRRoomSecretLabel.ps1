[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)] [String] $subscriptionId ='93564b8e-ff1e-480e-9374-e6970f79ceb1',
    [Parameter(Mandatory = $false)] [String] $keyVaultName = 'kv-mtr-accountsecret'
)

# Liten sjekk på om vi er pålogget og har tilgang, hvis ikke logg på
if (-not (Get-AzContext -ListAvailable | Where-Object { $_.Subscription.Id -eq $subscriptionId })) {
    Connect-AzAccount -SubscriptionId $subscriptionId
}

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

$secrets = try {
    Get-AzKeyVaultSecret -VaultName $keyVaultName
}
catch {
    Write-Error "Unable to get secrets from keyvault $keyVaultName`: $($_.Exception.Message)"
}

Write-Verbose "Found $($secrets.Count) secrets in keyvault $keyVaultName"

$secretsNoLabels = $secrets | Where-Object { $_.Tags.Count -eq 0 }

Write-Verbose "Found $($secretsNoLabels.Count) secrets without labels"

$output = foreach($secret in $secretsNoLabels) {
    $adUser = Get-AzADUser -UserPrincipalName "$($secret.Name)@nav.no" -ErrorAction SilentlyContinue
    $displayName = ""
    if($adUser.DisplayName -ne $null) {
        $displayName = $adUser.DisplayName
    }
    [PSCustomObject]@{
        Name = $secret.Name
        RoomName = $displayName
        Region = ""
        Location = ""
    }
}

$output | ConvertTo-Csv -Delimiter ";" -NoTypeInformation | Out-File "MTRRooms.csv" -Encoding UTF8 -Force