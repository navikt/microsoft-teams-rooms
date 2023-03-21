targetScope = 'subscription'

param solutionName string = deployment().name // set in deploy.ps1
param location string = deployment().location // set in deploy.ps1
param owner string = 'kenneth.sundby@nav.no' // will also be used for alert
param ResourceGroupName string = 'rg-${solutionName}'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ResourceGroupName
  location: location
  managedBy: owner
}

module storage 'storage.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${deployment().name}-SA'
  params: {
    solutionName: solutionName
    location: location
  }
}
