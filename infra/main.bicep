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

@description('Administrator login for the SQL Server')
param administratorLogin string

@secure()
@description('Administrator password for the SQL Server')
param administratorLoginPassword string

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

// Deploy SQL Database module
module sqlDbModule 'sqlDatabase.bicep' = {
  name: 'sqlDbDeployment'
  params: {
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    location: location
  }
}

output webAppEndpoint string = webAppModule.outputs.defaultHostName
output sqlServerFqdn string = sqlDbModule.outputs.sqlServerFullyQualifiedDomainName
