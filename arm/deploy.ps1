<#
PowerShell script to deploy ARM JSON templates from Azure Automation Runbook
# Requires: Az.Accounts, Az.Resources modules
# Uses Managed Identity of Automation Account for authentication
#>

param(
    [Parameter(Mandatory=$true)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string] $StorageAccountResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string] $StorageAccountName,
    [Parameter(Mandatory=$true)]
    [string] $StorageContainerName,
    [Parameter(Mandatory=$false)]
    [string] $JsonTemplateFileName = 'main.json'
)

Write-Output "Authenticating with Managed Identity..."
Connect-AzAccount -Identity
# Connect-AzAccount -Subscription '17a74f89-ae0b-4a43-a209-c5bba694fd49'

# Ensure the resource group exists, otherwise error out
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Error "Resource group '$ResourceGroupName' does not exist."
    exit 1
}

# Retrieve the existing resource group's location for deployment
$Location = (Get-AzResourceGroup -Name $ResourceGroupName).Location

# Download ARM JSON files from Blob Storage to temp
$jsonDir = Join-Path $env:TEMP 'armjson'
if (-not (Test-Path $jsonDir)) { New-Item -Path $jsonDir -ItemType Directory | Out-Null }
$ctx = (Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName).Context

# Download main template
Get-AzStorageBlobContent -Container $StorageContainerName -Blob $JsonTemplateFileName -Destination (Join-Path $jsonDir $JsonTemplateFileName) -Context $ctx -Force | Out-Null

# Download nested templates/modules
$blobs = Get-AzStorageBlob -Container $StorageContainerName -Context $ctx | Where-Object Name -like '*.json' | Where-Object Name -ne $JsonTemplateFileName
foreach ($blob in $blobs) {
    Get-AzStorageBlobContent -Container $StorageContainerName -Blob $blob.Name -Destination (Join-Path $jsonDir $blob.Name) -Context $ctx -Force | Out-Null
}

# Localize path to main ARM template
$templatePath = Join-Path $jsonDir $JsonTemplateFileName

# Deploy ARM template with what-if for validation
Write-Output "Validating deployment via What-If..."
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $templatePath -TemplateParameterObject @{
    webAppName = 'myWebApp'
    appServicePlanName = 'myPlan'
    sqlServerName = 'mySqlServer'
    sqlDatabaseName = 'myDatabase'
    administratorLogin = 'sqlAdmin'
    administratorLoginPassword = 'P@ssw0rd1234' # Should be replaced via secure parameter in Automation
    location = $Location
} -WhatIf

<# Perform actual deployment and capture outputs #>
Write-Output "Starting deployment..."
$deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $templatePath -TemplateParameterObject @{
    webAppName = 'myWebApp'
    appServicePlanName = 'myPlan'
    sqlServerName = 'mySqlServer'
    sqlDatabaseName = 'myDatabase'
    administratorLogin = 'sqlAdmin'
    administratorLoginPassword = 'P@ssw0rd1234'
    location = $Location
}

Write-Output "Deployment completed."
# Output endpoints from ARM template outputs
Write-Output "Web App URL: https://$($deployment.Outputs.webAppEndpoint.Value)"
Write-Output "SQL FQDN: $($deployment.Outputs.sqlServerFqdn.Value)"
