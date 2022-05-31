param solutionName string
param emailAddress string
param appInsightsId string

@description('Short name (maximum 12 characters) for the Action group.')
param actionGroupShortName string = 'NotifyOwner'

resource actionGroup 'Microsoft.Insights/actionGroups@2022-04-01' = {
  name: 'ag-${solutionName}'
  location: 'global'
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [
      {
        name: '${solutionName} Solution Owner'
        emailAddress: emailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

resource functionFailureAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Function Failure - ${solutionName}'
  location: 'global'
  properties: {
    severity: 1
    enabled: true
    scopes: [
      appInsightsId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT1H'
    criteria: {
      allOf: [
        {
          threshold: 1
          name: 'Metric1'
          metricNamespace: 'microsoft.insights/components'
          metricName: 'exceptions/count'
          operator: 'GreaterThan'
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'microsoft.insights/components'
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}
