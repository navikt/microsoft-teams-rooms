param solutionName string = deployment().name // set in deploy.ps1
param location string = deployment().location // set in deploy.ps1
param owner string = 'kenneth.sundby@nav.no' // will also be used for alert

@secure()
param funcAppTenantId string // set in deploy.ps1
@secure()
param funcAppAppId string // set in deploy.ps1
@secure()
param funcAppClientSecret string // set in deploy.ps1
@secure()
param funcAppTeamsHook string // set in deploy.ps1

param ResourceGroupName string = 'rg-${solutionName}'

targetScope = 'subscription'

resource newRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ResourceGroupName
  location: location
  managedBy: owner
}

module newFuncApp 'functionApp.bicep' = {
  scope: resourceGroup(newRG.name)
  name: 'newFuncApp-module'
  params: {
    location: location
    solutionName: solutionName
    // Links to secrets in the keyvault
    keyVaultSecret_TenantId: newKeyVault.outputs.keyVaultSecret_TenantId
    keyVaultSecret_AppId: newKeyVault.outputs.keyVaultSecret_AppId
    keyVaultSecret_ClientSecret: newKeyVault.outputs.keyVaultSecret_ClientSecret
    keyVaultSecret_teamsHook: newKeyVault.outputs.keyVaultSecret_teamsHook
  }
}

// Basic monitoring; if function fails a mail will be sent to owner
module newAlerts 'alerts.bicep' = {
  scope: resourceGroup(newRG.name)
  name: 'newAlerts-module'
  params: {
    appInsightsId: newFuncApp.outputs.appInsightsId
    solutionName: solutionName
    emailAddress: owner
  }
}

module newKeyVault 'keyvault.bicep' = {
  scope: resourceGroup(newRG.name)
  name: 'newKeyVault-module'
  params: {
    solutionName: solutionName
    location: location
    TenantId: funcAppTenantId
    AppId: funcAppAppId
    ClientSecret: funcAppClientSecret
    TeamsHook: funcAppTeamsHook
  }
}

// Access to keyvault for functionapp managed identity
module newKeyVaultAccess 'keyvault-access.bicep' = {
  scope: resourceGroup(newRG.name)
  name: 'newKeyVaultAccess-module'
  params: {
    keyVaultAccessObjectId: newFuncApp.outputs.identityId
    keyVaultName: newKeyVault.outputs.keyVaultName
    rg: newRG.name
  }
}

// Used by deploy.ps1 when uploading the function app files
output funcAppName string = newFuncApp.outputs.funcAppNamestring
output rg string = newRG.name
