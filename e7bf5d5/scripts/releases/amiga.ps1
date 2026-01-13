<#
.SYNOPSIS
    Amiga release configuration for AmiDevBox

.DESCRIPTION
    Specific build logic for AmiDevBox release. Copies DevBox system files
    and creates installation wrapper for end users.

.PARAMETER ReleaseDir
    Target release directory (dist/release)

.PARAMETER DevBoxDir
    Source DevBox directory (devbox)

.PARAMETER Version
    Release version number

.OUTPUTS
    PSCustomObject with release metadata (Name, Description, Repository)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ReleaseDir,

    [Parameter(Mandatory=$true)]
    [string]$DevBoxDir,

    [Parameter(Mandatory=$true)]
    [string]$BoxerVersion
)

$ErrorActionPreference = "Stop"

Write-Host "⚙️  Configuring Amiga release..." -ForegroundColor Cyan
Write-Host ""

# Release metadata
$ReleaseName = "AmiDevBox"
$ReleaseDescription = "Complete Amiga development environment setup system"
$ReleaseRepo = "https://github.com/vbuzzano/AmiDevBox"
$BoxPath = "boxers\AmiDevBox"

# Verify box structure exists
Write-Host "🔍 Verifying box structure..." -ForegroundColor Yellow

if (-not (Test-Path $BoxPath)) {
    Write-Host ""
    Write-Host "❌ Error: $BoxPath not found" -ForegroundColor Red
    Write-Host ""
    exit 1
}

if (-not (Test-Path "dist\box.ps1")) {
    Write-Host ""
    Write-Host "❌ Error: dist\box.ps1 not found" -ForegroundColor Red
    Write-Host "   Run: .\scripts\build-box.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

if (-not (Test-Path "dist\boxer.ps1")) {
    Write-Host ""
    Write-Host "❌ Error: dist\boxer.ps1 not found" -ForegroundColor Red
    Write-Host "   Run: .\scripts\build-boxer.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "   ✅ All compiled files found" -ForegroundColor Green
Write-Host ""

# Copy ONLY compiled files (no sources needed for end users)
Write-Host "📦 Copying release files..." -ForegroundColor Yellow

# Copy boxer.ps1 as main installer (self-installing, no template needed)
Write-Host "   boxer.ps1 (self-installing)..." -ForegroundColor Gray
if (-not (Test-Path "dist\boxer.ps1")) {
    Write-Host ""
    Write-Host "❌ Error: dist\boxer.ps1 not found" -ForegroundColor Red
    Write-Host "   Run: .\scripts\build-boxer.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
Copy-Item -Force "dist\boxer.ps1" "$ReleaseDir\boxer.ps1"

Write-Host "   box.ps1 (runtime)..." -ForegroundColor Gray
Copy-Item -Force "dist\box.ps1" "$ReleaseDir\box.ps1"

Write-Host "   config.psd1 (box configuration)..." -ForegroundColor Gray
Copy-Item -Force "$BoxPath\config.psd1" "$ReleaseDir\config.psd1"

Write-Host "   env.ps1 (environment configuration)..." -ForegroundColor Gray
Copy-Item -Force "$BoxPath\env.ps1" "$ReleaseDir\env.ps1"

# Read current version from SOURCE metadata
$sourceMetadataPath = "$BoxPath\metadata.psd1"
$sourceMetadata = Import-PowerShellDataFile $sourceMetadataPath
$currentVersion = $sourceMetadata.Version

# Increment build number
if ($currentVersion -match '(\d+)\.(\d+)\.(\d+)') {
    $major = $Matches[1]
    $minor = $Matches[2]
    $build = [int]$Matches[3]
    $build++
    $newVersion = "$major.$minor.$build"
    Write-Host "   Auto-incrementing version: $currentVersion → $newVersion" -ForegroundColor DarkGray
} else {
    throw "Invalid version format in source metadata: $currentVersion"
}

# Update SOURCE metadata FIRST (persist for next build)
Write-Host "   Updating source metadata..." -ForegroundColor Gray
$sourceContent = Get-Content $sourceMetadataPath -Raw
$sourceContent = $sourceContent -replace '(Version\s*=\s*")[^"]*', "`${1}$newVersion"
$sourceContent = $sourceContent -replace '(BoxerVersion\s*=\s*")[^"]*', "`${1}$BoxerVersion"
$sourceContent = $sourceContent -replace '(BuildDate\s*=\s*")[^"]*', "`${1}$(Get-Date -Format 'yyyy-MM-dd')"
$sourceContent | Set-Content $sourceMetadataPath -Encoding UTF8

# Copy updated metadata to release
Write-Host "   metadata.psd1 (box metadata)..." -ForegroundColor Gray
Copy-Item -Force "$BoxPath\metadata.psd1" "$ReleaseDir\metadata.psd1"

Write-Host "   tpl/ (template directory)..." -ForegroundColor Gray
if (Test-Path "$BoxPath\tpl") {
    $TplSource = Join-Path $BoxPath "tpl"
    $TplDest = Join-Path $ReleaseDir "tpl"

    Copy-Item -Path $TplSource -Destination $TplDest -Recurse -Force

    $fileCount = (Get-ChildItem -Path $TplDest -File -Recurse).Count
    if ($fileCount -eq 0) {
        throw "Release build failed: No files found in tpl/"
    }
    Write-Verbose "  Copied $fileCount template files"
}

# Copy root files
Write-Host ""
Write-Host "📄 Copying documentation and metadata..." -ForegroundColor Yellow
$rootFiles = @(
    @{Source = ".gitignore"; Dest = ".gitignore"},
    @{Source = "LICENSE"; Dest = "LICENSE"},
    @{Source = "CHANGELOG.md"; Dest = "CHANGELOG.md"}
)

foreach ($file in $rootFiles) {
    if (Test-Path $file.Source) {
        Write-Host "   $($file.Dest)..." -ForegroundColor Gray
        Copy-Item -Force $file.Source "$ReleaseDir\$($file.Dest)"
    }
}

# Copy release-specific README
Write-Host "   README.md (box documentation)..." -ForegroundColor Gray
if (Test-Path "$BoxPath\README.md") {
    Copy-Item -Force "$BoxPath\README.md" "$ReleaseDir\README.md"
} elseif (Test-Path "README.md") {
    Copy-Item -Force "README.md" "$ReleaseDir\README.md"
}

Write-Host ""
Write-Host "✅ Amiga release configured successfully" -ForegroundColor Green

# Read final metadata to return
$metadataPath = "$ReleaseDir\metadata.psd1"
$finalMetadata = Import-PowerShellDataFile $metadataPath

# Return metadata
[PSCustomObject]@{
    Name = $ReleaseName
    Description = $ReleaseDescription
    Repository = $ReleaseRepo
    Version = $finalMetadata.Version
    BoxerVersion = $finalMetadata.BoxerVersion
}
