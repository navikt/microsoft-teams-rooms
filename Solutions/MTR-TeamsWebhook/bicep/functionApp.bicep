param location string
param solutionName string

// URIs to keyvault
@secure()
param keyVaultSecret_TenantId string
@secure()
param keyVaultSecret_AppId string
@secure()
param keyVaultSecret_ClientSecret string
@secure()
param keyVaultSecret_teamsHook string

// Making sure the storage name is allowed...
@description('The name of the Storage Account')
param storageAccountName string = take(toLower(replace('st-${solutionName}-${uniqueString(resourceGroup().id)}', '-', '')), 24)

resource storageAccounts 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
    }
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: 'plan-${solutionName}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'functionapp'
  properties: {
    reserved: false // to set as linux app service
  }
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'log-${solutionName}'
  location: location
  properties: {}
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${solutionName}'
  location: location
  kind: 'web'
  properties: {
    WorkspaceResourceId: workspace.id
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: 'func-${solutionName}'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: hostingPlan.id
    siteConfig: {
      powerShellVersion: '~7'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccounts.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccounts.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccounts.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccounts.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'APPREG_TENANT'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultSecret_TenantId})'
        }
        {
          name: 'APPREG_APPID'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultSecret_AppId})'
        }
        {
          name: 'APPREG_CLIENTSECRET'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultSecret_ClientSecret})'
        }
        {
          name: 'TEAMSHOOK'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultSecret_teamsHook})'
        }
      ]
    }
  }
}

// used by main.bicep -> keyvault-access.bicep
output identityId string = functionApp.identity.principalId

// used by main.bicep -> alerts.bicep
output appInsightsId string = appInsights.id

// used by main.bicep -> deploy.ps1
output funcAppNamestring string = functionApp.name
