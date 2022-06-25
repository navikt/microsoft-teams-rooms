param (
    [string]$DeploymentName = "MTR-TeamsWebhook",
    [string]$Location = "norwayeast",
    [string]$TemplateFile = "$PSScriptRoot/bicep/main.bicep",
    [Parameter(Mandatory = $true)]
    [string]$subscription = ""
)

function Disconnect-AzureSubscription {
    Write-Host "Logger av"
    $null = Disconnect-AzAccount -Scope CurrentUser
}

#set context
$context = try {
    Set-AzContext $subscription
}
catch {
    Write-Warning "Unable to set subscription context, aborting"
    $_.Exception.Message
    exit 1
}
Write-Host "Working in context $($context.Subscription.Name) [$($context.Subscription.id)]"

# Deploy Bicep
$params = @{
    Name                  = $DeploymentName + '-' + (Get-Date -Format yyMMdd-HHmmss).ToString()
    TemplateFile          = $TemplateFile
    Location              = $Location
    TemplateParameterFile = "$PSScriptRoot/secrets.json"
}

Write-Host "Deploying $DeploymentName"

$deploy = New-AzDeployment @params -ErrorAction SilentlyContinue -ErrorVariable deployErr

if ($deploy.ProvisioningState -eq 'Succeeded') {
    Write-Host 'Deploy finished'
}
elseif ($deploy) {
    Write-Warning "Deployment did not finish as expected"
    $deploy
    exit 1
}
else {
    Write-Warning "Deploy failed!"
    $deployErr
    exit 1
}

## Function App deployment

$funcAppName = $deploy.Outputs["funcAppName"].Value
$rg = $deploy.Outputs["rg"].Value

$pArchive = @{
    Path            = "$PSScriptRoot/funcApp/*"
    DestinationPath = "$([io.path]::GetTempPath())/deploy_$($funcAppName).zip"
    PassThru        = $true
    Update          = $true
}

$zip = try {
    Write-Host "Oppretter zip-fil for function app [$($funcAppName)]"
    Compress-Archive @pArchive
}
catch {
    Write-Error "$($_.Exception.Message)"
    $null
}

if ($null -eq $zip) {
    Disconnect-AzureSubscription
    exit 1
}

$pPublish = @{
    Name              = $funcAppName
    ResourceGroupName = $rg
    ArchivePath       = $zip
    Force             = $true
}

$psSite = try {
    Write-Host "Deployer function app zip-fil [$($zip.Name)]"
    Publish-AzWebApp @pPublish
}
catch {
    Write-Error "$($_.Exception.Message)"
    $null
}

if ($null -eq $psSite) {
    Disconnect-AzureSubscription
    exit 1
}

Write-Host "Ferdig!"
Disconnect-AzureSubscription
exit 0