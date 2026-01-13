<#
.SYNOPSIS
    BoxBuilder - Creates new box structures

.DESCRIPTION
    Generates a complete box structure from templates.
    Creates boxers/<BoxName>/ with config, metadata, assets, and workspace template.

.PARAMETER Name
    Name of the box to create (e.g., "AmiDevBox", "PythonBox")

.PARAMETER Type
    Template type: minimal, dev, custom

.PARAMETER Path
    Output path (default: boxers/)

.EXAMPLE
    .\BoxBuilder\create-box.ps1 -Name "AmiDevBox" -Type "dev"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Name,

    [Parameter(Mandatory=$false)]
    [ValidateSet('minimal', 'dev', 'custom')]
    [string]$Type = 'minimal',

    [Parameter(Mandatory=$false)]
    [string]$Path = "boxers"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$BoxPath = Join-Path $RepoRoot "$Path\$Name"

Write-Host "`n📦 BoxBuilder - Creating $Name" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host ""

# Check if box already exists
if (Test-Path $BoxPath) {
    Write-Host "❌ Box already exists: $BoxPath" -ForegroundColor Red
    Write-Host "   Delete it first or use a different name." -ForegroundColor Yellow
    exit 1
}

# Load template
$templatePath = Join-Path $PSScriptRoot "templates\$Type"
if (-not (Test-Path $templatePath)) {
    Write-Host "❌ Template not found: $Type" -ForegroundColor Red
    exit 1
}

Write-Host "📋 Using template: $Type" -ForegroundColor Gray

# Create box structure
Write-Host "`n🔨 Creating box structure..." -ForegroundColor Cyan

New-Item -ItemType Directory -Path $BoxPath -Force | Out-Null
New-Item -ItemType Directory -Path "$BoxPath\assets" -Force | Out-Null
New-Item -ItemType Directory -Path "$BoxPath\workspace" -Force | Out-Null

Write-Host "✓ Created: $BoxPath" -ForegroundColor Green
Write-Host "✓ Created: $BoxPath\assets" -ForegroundColor Green
Write-Host "✓ Created: $BoxPath\workspace" -ForegroundColor Green

# Copy template files
Write-Host "`n📄 Copying template files..." -ForegroundColor Cyan

# Config
$configTemplate = Join-Path $templatePath "config.psd1"
if (Test-Path $configTemplate) {
    $config = Get-Content $configTemplate -Raw
    $config = $config -replace '{{BOX_NAME}}', $Name
    $config = $config -replace '{{BOX_TYPE}}', $Type
    $config | Set-Content -Path "$BoxPath\config.psd1" -Encoding UTF8
    Write-Host "✓ Created: config.psd1" -ForegroundColor Green
}

# Metadata
$metadataTemplate = Join-Path $templatePath "metadata.psd1"
if (Test-Path $metadataTemplate) {
    $metadata = Get-Content $metadataTemplate -Raw
    $metadata = $metadata -replace '{{BOX_NAME}}', $Name
    $metadata = $metadata -replace '{{BOX_TYPE}}', $Type
    $metadata = $metadata -replace '{{BUILD_DATE}}', (Get-Date -Format 'yyyy-MM-dd')
    $metadata | Set-Content -Path "$BoxPath\metadata.psd1" -Encoding UTF8
    Write-Host "✓ Created: metadata.psd1" -ForegroundColor Green
}

# Assets
$assetsTemplate = Join-Path $templatePath "assets"
if (Test-Path $assetsTemplate) {
    Get-ChildItem -Path $assetsTemplate -File | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        $content = $content -replace '{{BOX_NAME}}', $Name
        $content = $content -replace '{{BOX_TYPE}}', $Type
        $destPath = Join-Path "$BoxPath\assets" $_.Name
        $content | Set-Content -Path $destPath -Encoding UTF8
        Write-Host "✓ Created: assets\$($_.Name)" -ForegroundColor Green
    }
}

# Workspace
$workspaceTemplate = Join-Path $templatePath "workspace"
if (Test-Path $workspaceTemplate) {
    Copy-Item -Path "$workspaceTemplate\*" -Destination "$BoxPath\workspace" -Recurse -Force
    Write-Host "✓ Created: workspace structure" -ForegroundColor Green
}

# README
$readmeTemplate = Join-Path $templatePath "README.md"
if (Test-Path $readmeTemplate) {
    $readme = Get-Content $readmeTemplate -Raw
    $readme = $readme -replace '{{BOX_NAME}}', $Name
    $readme = $readme -replace '{{BOX_TYPE}}', $Type
    $readme | Set-Content -Path "$BoxPath\README.md" -Encoding UTF8
    Write-Host "✓ Created: README.md" -ForegroundColor Green
}

Write-Host "`n✅ Box created successfully!" -ForegroundColor Green
Write-Host "   Path: $BoxPath" -ForegroundColor Gray
Write-Host "`n📝 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Edit config.psd1 to configure packages and settings" -ForegroundColor Gray
Write-Host "   2. Add templates to assets/ directory" -ForegroundColor Gray
Write-Host "   3. Customize workspace/ structure" -ForegroundColor Gray
Write-Host "   4. Test with: boxer install $Name" -ForegroundColor Gray
Write-Host ""
