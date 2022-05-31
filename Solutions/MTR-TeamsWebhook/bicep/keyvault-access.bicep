param keyVaultName string
param rg string
param keyVaultAccessObjectId string

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: keyVaultName
  scope: resourceGroup(rg)
}

// Get the role we want to use
@description('Key Vault Secrets User: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
resource KeyVaultSecretsUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: keyVault
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

// Gives the functionapp's managed identity the role above
// TODO: Something unexpected happening here: access is granted on resource group level instead of on keyvault level
// I suspect this is something inherited from me deploying on the subscription scope initially?
resource keyVaultAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(subscription().id, KeyVaultSecretsUserRoleDefinition.id, keyVaultAccessObjectId)
  properties: {
    principalId: keyVaultAccessObjectId
    roleDefinitionId: KeyVaultSecretsUserRoleDefinition.id
  }
}
