# PowerShell script to deploy infrastructure using pre-converted ARM templates
# Designed for Azure Automation Runbook execution
# Requires: Az.Accounts, Az.Resources modules
# NOTE: ARM templates must be pre-converted from Bicep using build-arm.ps1

param(
    [Parameter(Mandatory=$true)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string] $StorageAccountResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string] $StorageAccountName,
    [Parameter(Mandatory=$true)]
    [string] $StorageContainerName,
    [Parameter(Mandatory=$true)]
    [string] $SqlAdminEntraObjectId,
    [Parameter(Mandatory=$true)]
    [string] $SQLAdminEntraUPN,
    [Parameter(Mandatory=$false)]
    [string] $MainTemplateFileName = 'main.json'
)

Write-Output "=== Azure Infrastructure Deployment (ARM Templates) ==="
Write-Output "Resource Group: $ResourceGroupName"
Write-Output "Storage Account: $StorageAccountName"
Write-Output "Container: $StorageContainerName"
Write-Output "Main Template: $MainTemplateFileName"
Write-Output ""
Write-Output "IMPORTANT: ARM templates must be pre-converted from Bicep using build-arm.ps1"

Write-Output "Authenticating with Managed Identity..."
Connect-AzAccount -Identity

# Ensure the resource group exists, otherwise error out
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Error "Resource group '$ResourceGroupName' does not exist."
    exit 1
}

# Retrieve the existing resource group's location for deployment
$Location = (Get-AzResourceGroup -Name $ResourceGroupName).Location
Write-Output "Deployment location: $Location"

Write-Output "SQL Server will be configured with Entra ID authentication only"
Write-Output "Entra ID Admin Object ID: $SqlAdminEntraObjectId"
Write-Output "Entra ID Admin Login: $SQLAdminEntraUPN"

# Step 1: Download ARM templates from Blob Storage
Write-Output "Step 1: Downloading ARM templates from Blob Storage..."
$armDir = Join-Path $env:TEMP 'arm-templates'
if (Test-Path $armDir) { Remove-Item -Path $armDir -Recurse -Force }
New-Item -Path $armDir -ItemType Directory | Out-Null

$ctx = (Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName).Context
$blobs = Get-AzStorageBlob -Container $StorageContainerName -Context $ctx | Where-Object Name -like '*.json'

if ($blobs.Count -eq 0) {
    Write-Error "No ARM template files (*.json) found in container: $StorageContainerName"
    Write-Error "Please ensure ARM templates are pre-converted and uploaded using upload-templates.ps1"
    exit 1
}

foreach ($blob in $blobs) {
    Write-Output "  Downloading: $($blob.Name)"
    Get-AzStorageBlobContent -Container $StorageContainerName -Blob $blob.Name -Destination (Join-Path $armDir $blob.Name) -Context $ctx -Force | Out-Null
}

# Verify main template exists
$mainTemplatePath = Join-Path $armDir $MainTemplateFileName
if (-not (Test-Path $mainTemplatePath)) {
    Write-Error "Main ARM template not found: $mainTemplatePath"
    $availableFiles = Get-ChildItem -Path $armDir -Name
    Write-Error "Available files: $($availableFiles -join ', ')"
    Write-Error "Please ensure the main template '$MainTemplateFileName' is uploaded to Blob Storage"
    exit 1
}

Write-Output "  Main template found: $MainTemplateFileName"
Write-Output "  Additional templates: $(($blobs | Where-Object Name -ne $MainTemplateFileName | Select-Object -ExpandProperty Name) -join ', ')"

# Step 2: Deploy ARM template
Write-Output "Step 2: Deploying ARM template..."

# Deployment parameters
$deploymentParams = @{
    webAppName = 'myWebApp'
    appServicePlanName = 'myPlan'
    sqlServerName = 'mySqlServer'
    sqlDatabaseName = 'myDatabase'
    entraAdminObjectId = $SqlAdminEntraObjectId
    entraAdminLoginName = $SQLAdminEntraUPN
    location = $Location
}

Write-Output "  Deployment parameters configured:"
Write-Output "    - Web App Name: $($deploymentParams.webAppName)"
Write-Output "    - SQL Server Name: $($deploymentParams.sqlServerName)"
Write-Output "    - Entra Admin Object ID: $($deploymentParams.entraAdminObjectId)"
Write-Output "    - Entra Admin Login: $($deploymentParams.entraAdminLoginName)"
Write-Output "  Starting deployment to resource group: $ResourceGroupName"

try {
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $mainTemplatePath `
        -TemplateParameterObject $deploymentParams `
        -Name "AutomationDeployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
        -Verbose

    Write-Output "=== Deployment completed successfully ==="
    
    # Output deployment results
    if ($deployment.Outputs) {
        Write-Output "Deployment outputs:"
        if ($deployment.Outputs.webAppEndpoint) {
            Write-Output "  Web App URL: https://$($deployment.Outputs.webAppEndpoint.Value)"
        }
        if ($deployment.Outputs.sqlServerFqdn) {
            Write-Output "  SQL Server FQDN: $($deployment.Outputs.sqlServerFqdn.Value)"
        }
        if ($deployment.Outputs.entraIdInfo) {
            Write-Output "  Authentication: $($deployment.Outputs.entraIdInfo.Value.message)"
            Write-Output "  Admin Login: $($deployment.Outputs.entraIdInfo.Value.adminLogin)"
        }
    }
    
    Write-Output ""
    Write-Output "SQL Server Authentication Configuration:"
    Write-Output "  Authentication Type: Entra ID Only"
    Write-Output "  Login Name: $SQLAdminEntraUPN"
    Write-Output "  Object ID: $SqlAdminEntraObjectId"
    Write-Output "  IMPORTANT: SQL Authentication is disabled. Use Entra ID authentication only."
    
} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    if ($_.Exception.InnerException) {
        Write-Error "Inner exception: $($_.Exception.InnerException.Message)"
    }
    throw
} finally {
    # Cleanup temporary files
    Write-Output "Cleaning up temporary files..."
    if (Test-Path $armDir) { 
        Remove-Item -Path $armDir -Recurse -Force -ErrorAction SilentlyContinue 
        Write-Output "  Temporary ARM templates cleaned up"
    }
}

Write-Output "=== Deployment process completed ==="
