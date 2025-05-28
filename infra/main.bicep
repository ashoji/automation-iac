// Main Bicep template to deploy Azure Web App and SQL Database
// Implements separation of concerns by using modules for each resource

@description('Name of the Web App')
param webAppName string

@description('Name of the App Service Plan')
param appServicePlanName string

@description('Name of the SQL Server')
param sqlServerName string

@description('Name of the SQL Database')
param sqlDatabaseName string

@description('Entra ID administrator object ID for SQL Server')
param entraAdminObjectId string

@description('Entra ID administrator login name (email or UPN) for SQL Server')
param entraAdminLoginName string

@description('Location for all resources')
param location string = resourceGroup().location

// Deploy Web App module
module webAppModule 'webApp.bicep' = {
  name: 'webAppDeployment'
  params: {
    webAppName: webAppName
    appServicePlanName: appServicePlanName
    location: location
  }
}

// Deploy SQL Database module with Entra ID authentication
module sqlDbModule 'sqlDatabase.bicep' = {
  name: 'sqlDbDeployment'
  params: {
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    entraAdminObjectId: entraAdminObjectId
    entraAdminLoginName: entraAdminLoginName
    location: location
  }
}

// Output resources information
output webAppEndpoint string = webAppModule.outputs.defaultHostName
output sqlServerFqdn string = sqlDbModule.outputs.sqlServerFullyQualifiedDomainName
output entraIdInfo object = {
  message: 'SQL Server configured with Entra ID authentication only'
  adminLogin: entraAdminLoginName
}
