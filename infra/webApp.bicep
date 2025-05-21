// Module to deploy Azure App Service Plan and Web App

@description('Name of the Web App')
param webAppName string

@description('Name of the App Service Plan')
param appServicePlanName string

@description('Location for resources')
param location string

var webAppNameUnique = '${webAppName}${uniqueString(resourceGroup().id)}'

// App Service Plan: Standard S1 for balanced performance
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'F1'
    tier: 'Standard'
  }
  properties: {
    reserved: false
  }
}

// Web App: Run on Windows, uses managed identity for secure access to SQL
resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: webAppNameUnique
  location: location
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      ipSecurityRestrictionsDefaultAction: 'Deny'
    }
  }
}

// Output default host name
output defaultHostName string = webApp.properties.defaultHostName
