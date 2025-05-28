// Module to deploy Azure App Service Plan and Web App with enhanced security

@description('Name of the Web App')
param webAppName string

@description('Name of the App Service Plan')
param appServicePlanName string

@description('Location for resources')
param location string

var webAppNameUnique = '${webAppName}${uniqueString(resourceGroup().id)}'

// App Service Plan: Free tier for demonstration (upgrade to Standard for production)
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'F1'
    tier: 'Free'
  }
  properties: {
    reserved: false
  }
}

// Web App: Enhanced security configuration with managed identity
resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: webAppNameUnique
  location: location
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      ipSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
      alwaysOn: false // Free tier doesn't support Always On
      detailedErrorLoggingEnabled: true
      httpLoggingEnabled: true
      requestTracingEnabled: true
    }
    clientAffinityEnabled: false
  }
}

// Output default host name and additional info
output defaultHostName string = webApp.properties.defaultHostName
output webAppId string = webApp.id
output managedIdentityPrincipalId string = webApp.identity.principalId
