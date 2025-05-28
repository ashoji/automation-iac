# Script to build ARM JSON templates from Bicep files
# This script helps developers generate ARM templates locally for testing and uploading to Blob Storage

param(
    [Parameter(Mandatory=$false)]
    [string] $OutputPath = ".\arm",
    [Parameter(Mandatory=$false)]
    [switch] $CleanOutput
)

Write-Output "=== Building ARM templates from Bicep ==="

# Ensure output directory exists
if ($CleanOutput -and (Test-Path $OutputPath)) {
    Write-Output "Cleaning output directory: $OutputPath"
    Remove-Item -Path $OutputPath -Recurse -Force
}

if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory | Out-Null
}

# Check if Bicep CLI is available
try {
    $bicepVersion = & bicep --version 2>$null
    Write-Output "Using Bicep CLI: $bicepVersion"
} catch {
    Write-Error "Bicep CLI not found. Please install Bicep CLI first."
    Write-Output "Installation instructions: https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install"
    exit 1
}

# Build all Bicep files in infra directory
$infraPath = ".\infra"
if (-not (Test-Path $infraPath)) {
    Write-Error "Infra directory not found: $infraPath"
    exit 1
}

$bicepFiles = Get-ChildItem -Path $infraPath -Filter "*.bicep"
if ($bicepFiles.Count -eq 0) {
    Write-Warning "No Bicep files found in $infraPath"
    exit 0
}

Write-Output "Found $($bicepFiles.Count) Bicep files to build:"

foreach ($bicepFile in $bicepFiles) {
    $outputFile = Join-Path $OutputPath ($bicepFile.BaseName + ".json")
    Write-Output "  Building: $($bicepFile.Name) -> $($bicepFile.BaseName).json"
    
    try {
        & bicep build $bicepFile.FullName --outfile $outputFile
        if ($LASTEXITCODE -eq 0) {
            Write-Output "    ✓ Success"
        } else {
            Write-Warning "    ✗ Failed with exit code: $LASTEXITCODE"
        }
    } catch {
        Write-Warning "    ✗ Error: $($_.Exception.Message)"
    }
}

# List generated files
Write-Output ""
Write-Output "Generated ARM templates in ${OutputPath}:"
$generatedFiles = Get-ChildItem -Path $OutputPath -Filter "*.json"
foreach ($file in $generatedFiles) {
    $size = [math]::Round($file.Length / 1KB, 2)
    Write-Output "  $($file.Name) ($size KB)"
}

Write-Output ""
Write-Output "=== Build completed ==="
Write-Output "Next steps:"
Write-Output "1. Review the generated ARM templates in the '${OutputPath}' directory"
Write-Output "2. Upload the templates to Azure Blob Storage for Azure Automation use"
Write-Output "3. Run the main deploy.ps1 script from Azure Automation"
