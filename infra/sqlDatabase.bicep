// Module to deploy SQL Server and SQL Database with Entra ID authentication only

@description('Name of the SQL Server')
param sqlServerName string

@description('Name of the SQL Database')
param sqlDatabaseName string

@description('Entra ID administrator object ID')
param entraAdminObjectId string

@description('Entra ID administrator login name (email or UPN)')
param entraAdminLoginName string

@description('Location for resources')
param location string

// Generate a unique name for the SQL Server
var sqlServerNameUnique = '${sqlServerName}${uniqueString(resourceGroup().id)}'

// SQL Server: Entra ID authentication only configuration
resource sqlServer 'Microsoft.Sql/servers@2024-05-01-preview' = {
  name: sqlServerNameUnique
  location: location
  properties: {
    version: '12.0'
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'
    azureADOnlyAuthentication: true
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'User'
      login: entraAdminLoginName
      sid: entraAdminObjectId
      tenantId: subscription().tenantId
    }
  }
}

// SQL Database: Basic tier with backup and security settings
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
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
    isLedgerOn: false
  }
}

// Enable Advanced Threat Protection
resource threatDetection 'Microsoft.Sql/servers/securityAlertPolicies@2024-05-01-preview' = {
  name: 'default'
  parent: sqlServer
  properties: {
    state: 'Enabled'
    emailAddresses: []
    emailAccountAdmins: false
    retentionDays: 30
  }
}

// Note: Vulnerability Assessment requires a storage account for scan results
// This can be enabled in production with proper storage configuration

// Output SQL Server information
output sqlServerFullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName
output sqlServerId string = sqlServer.id
output sqlDatabaseId string = sqlDatabase.id
