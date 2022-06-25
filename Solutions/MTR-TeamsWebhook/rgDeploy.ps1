param (
    [string]$DeploymentName = "MTR-TeamsWebhook",
    [string]$ResourceGroupName,
    [string]$TemplateFile = "$PSScriptRoot/bicep/main.bicep",
    [string]$TemplateParameterFile,
    [string]$Location = "norwayeast"
)

$ErrorActionPreference = 'Stop'

function Disconnect-AzureSubscription {
    Write-Host "Logging off"
    $null = Disconnect-AzAccount -Scope CurrentUser
}

#get context
$context = try {
    Get-AzContext
}
catch {
    Write-Warning "Unable to set subscription context, aborting"
    $Error[0].Exception.Message
    exit 1
}
Write-Host "Working in context $($context.Subscription.Name) [$($context.Subscription.id)]"

#create resource group
Write-Host "Checking for existence of resource group $resourceGroupName"
$rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if ($rg) {
    Write-Host "Resource group $resourceGroupName exists"
}
else {
    Write-Host "Resource group $rgName not found - creating it..."
    $subTags = Get-AzTag -ResourceId "/subscriptions/$($context.Subscription.Id)"
    [hashtable]$tags = $subTags.Properties.TagsProperty
    try {
        New-AzResourceGroup -Name $resourceGroupName -Location $Location -Tag $tags
    }
    catch {
        Write-Warning "Unable to create resource group:"
        $Error[0].Exception.Message
        exit 1
    }
}

#check for parameter file
Write-Host "Checking for existence of parameter file"
try {
    Test-Path -Path $TemplateParameterFile
    Write-Host 'Parameter file found, continuing...'
}
catch {
    Write-Error "Parameter file not found!"
    exit 1
}

# Deploy Bicep
$params = @{
    Name                  = $DeploymentName + '-' + (Get-Date -Format yyMMdd-HHmmss).ToString()
    TemplateFile          = $TemplateFile
    TemplateParameterFile = $TemplateParameterFile
    ResourceGroupName     = $ResourceGroupName
}

Write-Host "Deploying $DeploymentName"

$deploy = New-AzResourceGroupDeployment @params

if ($deploy.ProvisioningState -eq 'Succeeded') {
    Write-Host 'Deploy finished'
    $deploy
    exit 0
}
elseif ($deploy) {
    Write-Warning "Deployment did not finish as expected"
    $deploy
    $deployOperation = (Get-AzResourceGroupDeploymentOperation -DeploymentName $params.Name -ResourceGroupName $params.ResourceGroupName)

    Write-Host "Printing out status code and status message"
    $deployOperation.StatusCode
    $deployOperation.StatusMessage
    exit 1
}
else {
    Write-Warning "Deploy failed!"
    $error[0]
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
    Write-Host "Creating zip-file for function app [$($funcAppName)]"
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
    Write-Host "Deploying function app zip-file [$($zip.Name)]"
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

Write-Host "Done!"
Disconnect-AzureSubscription
exit 0