param solutionName string
param location string
param storageAccountBlobContainerName string = 'filer'

// Mye greier for å ha et navn som er lovlig og unikt :P
param storageAccountName string = take(toLower(replace('${solutionName}-st-${uniqueString(resourceGroup().id)}', '-', '')), 24)

resource storageAccounts 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  tags: resourceGroup().tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    accessTier: 'Hot'
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

resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-08-01' = {
  name: '${storageAccounts.name}/default/${storageAccountBlobContainerName}'
}

output storageAccountName string = storageAccounts.name
output storageContainerName string = storageContainer.name
output fileURI string = '${storageAccounts.properties.primaryEndpoints.blob}${storageAccountBlobContainerName}'
