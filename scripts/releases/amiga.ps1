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

    [string]$Version = "0.1.0"
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

if (-not (Test-Path "dist\devbox.ps1")) {
    Write-Host ""
    Write-Host "❌ Error: dist\devbox.ps1 not found" -ForegroundColor Red
    Write-Host "   devbox.ps1 should be in dist/ directory" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "   ✅ All compiled files found" -ForegroundColor Green
Write-Host ""

# Copy ONLY compiled files (no sources needed for end users)
Write-Host "📦 Copying release files..." -ForegroundColor Yellow

# Generate install.ps1 from template
Write-Host "   install.ps1 (generating from template)..." -ForegroundColor Gray
if (-not (Test-Path "tpl\install.ps1")) {
    Write-Host ""
    Write-Host "❌ Error: tpl\install.ps1 not found" -ForegroundColor Red
    Write-Host ""
    exit 1
}

$installTemplate = Get-Content "tpl\install.ps1" -Raw
$installTemplate = $installTemplate -replace '\{BOXING_REPO_URL\}', 'https://github.com/vbuzzano/Boxing'
$installTemplate = $installTemplate -replace '\{BOX_NAME\}', 'AmiDevBox'
$installTemplate = $installTemplate -replace '\{BOX_REPO_URL\}', 'https://github.com/vbuzzano/AmiDevBox'
Set-Content "$ReleaseDir\install.ps1" $installTemplate -Encoding UTF8

Write-Host "   boxer.ps1 (installer)..." -ForegroundColor Gray
Copy-Item -Force "dist\boxer.ps1" "$ReleaseDir\boxer.ps1"

Write-Host "   box.ps1 (runtime)..." -ForegroundColor Gray
Copy-Item -Force "dist\box.ps1" "$ReleaseDir\box.ps1"

Write-Host "   config.psd1 (box configuration)..." -ForegroundColor Gray
Copy-Item -Force "$BoxPath\config.psd1" "$ReleaseDir\config.psd1"

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

# Return metadata
[PSCustomObject]@{
    Name = $ReleaseName
    Description = $ReleaseDescription
    Repository = $ReleaseRepo
    Version = $Version
}
