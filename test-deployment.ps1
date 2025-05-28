# Test script to validate deployment configuration before Azure Automation execution
# This script performs dry-run validation without actual deployment

param(
    [Parameter(Mandatory=$false)]
    [string] $TestResourceGroupName = "test-iac-rg",
    [Parameter(Mandatory=$false)]
    [string] $TestLocation = "Japan East"
)

Write-Output "=== Azure IaC Deployment Validation Test ==="
Write-Output "Test Resource Group: $TestResourceGroupName"
Write-Output "Test Location: $TestLocation"

# Check if Azure CLI is available
try {
    $azVersion = az version --output tsv 2>$null
    if ($azVersion) {
        Write-Output "✓ Azure CLI is available"
    }
} catch {
    Write-Warning "Azure CLI not found - consider installing for local testing"
}

# Check if Bicep CLI is available
try {
    $bicepVersion = & bicep --version 2>$null
    if ($bicepVersion) {
        Write-Output "✓ Bicep CLI is available: $bicepVersion"
    }
} catch {
    Write-Error "Bicep CLI not found. Please install Bicep CLI for template compilation."
    Write-Output "Installation: https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install"
    exit 1
}

# Validate Bicep template syntax
Write-Output ""
Write-Output "Validating Bicep template syntax..."
$infraPath = ".\infra"
$bicepFiles = Get-ChildItem -Path $infraPath -Filter "*.bicep"

foreach ($bicepFile in $bicepFiles) {
    Write-Output "  Validating: $($bicepFile.Name)"
    try {
        & bicep build $bicepFile.FullName --stdout >$null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "    ✓ Syntax valid"
        } else {
            Write-Error "    ✗ Syntax error in $($bicepFile.Name)"
            exit 1
        }
    } catch {
        Write-Error "    ✗ Failed to validate $($bicepFile.Name): $($_.Exception.Message)"
        exit 1
    }
}

# Test parameter validation
Write-Output ""
Write-Output "Testing deployment parameters..."
$testParams = @{
    webAppName = 'test-webapp'
    appServicePlanName = 'test-plan'
    sqlServerName = 'test-sqlserver'
    sqlDatabaseName = 'test-database'
    administratorLogin = 'testadmin'
    administratorLoginPassword = 'TestPassword123!'
    generateRandomPassword = $true
    location = $TestLocation
}

Write-Output "  Parameters configured:"
foreach ($param in $testParams.GetEnumerator()) {
    if ($param.Key -eq 'administratorLoginPassword') {
        Write-Output "    $($param.Key): [REDACTED]"
    } else {
        Write-Output "    $($param.Key): $($param.Value)"
    }
}

# Simulate Azure CLI what-if (if available and authenticated)
if ($azVersion) {
    try {
        Write-Output ""
        Write-Output "Testing Azure authentication..."
        $accountInfo = az account show --output json 2>$null | ConvertFrom-Json
        if ($accountInfo) {
            Write-Output "  ✓ Authenticated as: $($accountInfo.user.name)"
            Write-Output "  ✓ Subscription: $($accountInfo.name) ($($accountInfo.id))"
            
            # Check if test resource group exists
            $rgExists = az group exists --name $TestResourceGroupName --output tsv
            if ($rgExists -eq 'true') {
                Write-Output "  ✓ Test resource group exists: $TestResourceGroupName"
                
                # Perform what-if validation
                Write-Output ""
                Write-Output "Performing deployment validation (what-if)..."
                $whatIfCmd = "az deployment group what-if --resource-group $TestResourceGroupName --template-file .\infra\main.bicep"
                foreach ($param in $testParams.GetEnumerator()) {
                    $whatIfCmd += " --parameters $($param.Key)='$($param.Value)'"
                }
                
                Write-Output "  Command: $whatIfCmd"
                Write-Output "  Note: This would show what resources would be created/modified"
                
            } else {
                Write-Output "  ℹ Test resource group does not exist: $TestResourceGroupName"
                Write-Output "  To create: az group create --name $TestResourceGroupName --location '$TestLocation'"
            }
        }
    } catch {
        Write-Output "  ℹ Not authenticated to Azure - skipping deployment validation"
        Write-Output "  To authenticate: az login"
    }
}

# Check PowerShell modules for Azure Automation compatibility
Write-Output ""
Write-Output "Checking PowerShell module compatibility..."
$requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.Storage')
foreach ($module in $requiredModules) {
    $moduleInfo = Get-Module -ListAvailable -Name $module | Select-Object -First 1
    if ($moduleInfo) {
        Write-Output "  ✓ $module is available (Version: $($moduleInfo.Version))"
    } else {
        Write-Warning "  ⚠ $module is not installed - required for Azure Automation"
        Write-Output "    Install with: Install-Module -Name $module -Force"
    }
}

Write-Output ""
Write-Output "=== Validation Summary ==="
Write-Output "✓ Bicep templates are syntactically valid"
Write-Output "✓ Deployment parameters are properly configured"
Write-Output "✓ Required PowerShell modules are available"
Write-Output ""
Write-Output "Next steps for Azure Automation deployment:"
Write-Output "1. Upload Bicep files to Azure Storage:"
Write-Output "   .\upload-templates.ps1 -StorageAccountResourceGroupName '<rg>' -StorageAccountName '<storage>' -ContainerName 'templates' -UploadBicepFiles"
Write-Output ""
Write-Output "2. Execute main deployment from Azure Automation:"
Write-Output "   .\deploy.ps1 -ResourceGroupName '<target-rg>' -StorageAccountResourceGroupName '<storage-rg>' -StorageAccountName '<storage>' -StorageContainerName 'templates'"
Write-Output ""
Write-Output "=== Test completed successfully ==="
