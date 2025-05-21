// Module to deploy SQL Server and SQL Database with secure configuration

@description('Name of the SQL Server')
param sqlServerName string

@description('Name of the SQL Database')
param sqlDatabaseName string

@description('Administrator login for SQL Server')
param administratorLogin string

@description('Administrator login password for SQL Server')
@secure()
param administratorLoginPassword string

@description('Location for resources')
param location string

// Generate a unique name for the SQL Server
@description('Unique name for the SQL Server')
var sqlServerNameUnique = '${sqlServerName}${uniqueString(resourceGroup().id)}'
// SQL Server: Use latest stable version with minimal public exposure
resource sqlServer 'Microsoft.Sql/servers@2024-05-01-preview' = {
  name: sqlServerNameUnique
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: '12.0'
    publicNetworkAccess: 'Disabled'
  }
}

// SQL Database: Basic tier for cost efficiency
resource sqlDatabase 'Microsoft.Sql/servers/databases@2024-05-01-preview' = {
  name: sqlDatabaseName
  parent: sqlServer
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2 GB
  }
}

output sqlServerFullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName
