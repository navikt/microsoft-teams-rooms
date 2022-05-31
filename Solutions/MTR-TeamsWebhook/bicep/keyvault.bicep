param location string = resourceGroup().location
param solutionName string
param keyVaultURI string = take(toLower(replace('kv-${solutionName}-${uniqueString(resourceGroup().id)}', '-', '')), 24)

param TenantId string
@secure()
param AppId string
@secure()
param ClientSecret string
@secure()
param TeamsHook string

resource newKeyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: 'kv-${solutionName}'
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: []
    tenantId: subscription().tenantId
    vaultUri: 'https://${keyVaultURI}${environment().suffixes.keyvaultDns}/'
    enableRbacAuthorization: true
    enabledForTemplateDeployment: true
  }
}

resource keyVaultSecret_TenantId 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  parent: newKeyVault
  name: '${solutionName}-TenantId'
  properties: {
    value: TenantId
  }
}
resource keyVaultSecret_AppId 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  parent: newKeyVault
  name: '${solutionName}-AppId'
  properties: {
    value: AppId
  }
}
resource keyVaultSecret_ClientSecret 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  parent: newKeyVault
  name: '${solutionName}-ClientSecret'
  properties: {
    value: ClientSecret
  }
}
resource keyVaultSecret_teamsHook 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  parent: newKeyVault
  name: '${solutionName}-TeamsHook'
  properties: {
    value: TeamsHook
  }
}

// used by main.bicep -> keyvault-access.bicep
output keyVaultName string = newKeyVault.name

// used by main.bicep -> functionApp.bicep
output keyVaultSecret_TenantId string = keyVaultSecret_TenantId.properties.secretUri
output keyVaultSecret_AppId string = keyVaultSecret_AppId.properties.secretUri
output keyVaultSecret_ClientSecret string = keyVaultSecret_ClientSecret.properties.secretUri
output keyVaultSecret_teamsHook string = keyVaultSecret_teamsHook.properties.secretUri
