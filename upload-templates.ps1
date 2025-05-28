# Script to upload ARM templates and Bicep files to Azure Blob Storage
# This prepares templates for Azure Automation deployment

param(
    [Parameter(Mandatory=$true)]
    [string] $StorageAccountResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string] $StorageAccountName,
    [Parameter(Mandatory=$true)]
    [string] $ContainerName,
    [Parameter(Mandatory=$false)]
    [string] $BicepSourcePath = ".\infra",
    [Parameter(Mandatory=$false)]
    [string] $ArmSourcePath = ".\arm",
    [Parameter(Mandatory=$false)]
    [switch] $UploadBicepFiles = $true,
    [Parameter(Mandatory=$false)]
    [switch] $UploadArmFiles = $false
)

Write-Output "=== Uploading templates to Azure Blob Storage ==="
Write-Output "Storage Account: $StorageAccountName"
Write-Output "Container: $ContainerName"

# Authenticate to Azure (use Connect-AzAccount if not already authenticated)
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Output "Not authenticated to Azure. Please run Connect-AzAccount first."
        Connect-AzAccount
    }
    Write-Output "Using Azure context: $($context.Account.Id)"
} catch {
    Write-Error "Failed to authenticate to Azure: $($_.Exception.Message)"
    exit 1
}

# Get storage account context
try {
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName
    $ctx = $storageAccount.Context
    Write-Output "Storage account context obtained successfully"
} catch {
    Write-Error "Failed to get storage account context: $($_.Exception.Message)"
    exit 1
}

# Ensure container exists
try {
    $container = Get-AzStorageContainer -Name $ContainerName -Context $ctx -ErrorAction SilentlyContinue
    if (-not $container) {
        Write-Output "Creating container: $ContainerName"
        New-AzStorageContainer -Name $ContainerName -Context $ctx -Permission Off | Out-Null
    } else {
        Write-Output "Container already exists: $ContainerName"
    }
} catch {
    Write-Error "Failed to create/access container: $($_.Exception.Message)"
    exit 1
}

$uploadCount = 0

# Upload Bicep files if requested
if ($UploadBicepFiles) {
    Write-Output ""
    Write-Output "Uploading Bicep files from $BicepSourcePath..."
    
    if (Test-Path $BicepSourcePath) {
        $bicepFiles = Get-ChildItem -Path $BicepSourcePath -Filter "*.bicep"
        foreach ($file in $bicepFiles) {
            try {
                Write-Output "  Uploading: $($file.Name)"
                Set-AzStorageBlobContent `
                    -File $file.FullName `
                    -Container $ContainerName `
                    -Blob $file.Name `
                    -Context $ctx `
                    -Force | Out-Null
                $uploadCount++
            } catch {
                Write-Warning "  Failed to upload $($file.Name): $($_.Exception.Message)"
            }
        }
    } else {
        Write-Warning "Bicep source path not found: $BicepSourcePath"
    }
}

# Upload ARM JSON files if requested
if ($UploadArmFiles) {
    Write-Output ""
    Write-Output "Uploading ARM JSON files from $ArmSourcePath..."
    
    if (Test-Path $ArmSourcePath) {
        $armFiles = Get-ChildItem -Path $ArmSourcePath -Filter "*.json"
        foreach ($file in $armFiles) {
            try {
                Write-Output "  Uploading: $($file.Name)"
                Set-AzStorageBlobContent `
                    -File $file.FullName `
                    -Container $ContainerName `
                    -Blob $file.Name `
                    -Context $ctx `
                    -Force | Out-Null
                $uploadCount++
            } catch {
                Write-Warning "  Failed to upload $($file.Name): $($_.Exception.Message)"
            }
        }
    } else {
        Write-Warning "ARM source path not found: $ArmSourcePath"
    }
}

# List uploaded files
Write-Output ""
Write-Output "Files in container '$ContainerName':"
try {
    $blobs = Get-AzStorageBlob -Container $ContainerName -Context $ctx
    foreach ($blob in $blobs) {
        $size = [math]::Round($blob.Length / 1KB, 2)
        $lastModified = $blob.LastModified.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Output "  $($blob.Name) ($size KB) - Modified: $lastModified"
    }
} catch {
    Write-Warning "Failed to list container contents: $($_.Exception.Message)"
}

Write-Output ""
Write-Output "=== Upload completed ==="
Write-Output "Uploaded $uploadCount files successfully"
Write-Output ""
Write-Output "Next steps:"
Write-Output "1. Run the main deploy.ps1 script from Azure Automation with these parameters:"
Write-Output "   - ResourceGroupName: [Target Resource Group]"
Write-Output "   - StorageAccountResourceGroupName: $StorageAccountResourceGroupName"
Write-Output "   - StorageAccountName: $StorageAccountName"
Write-Output "   - StorageContainerName: $ContainerName"
