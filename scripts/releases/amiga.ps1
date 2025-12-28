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

# Verify compiled files exist
Write-Host "🔍 Verifying compiled files..." -ForegroundColor Yellow

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

Write-Host "   box.ps1 (compiled, all-in-one)..." -ForegroundColor Gray
Copy-Item -Force "dist\box.ps1" "$ReleaseDir\box.ps1"

Write-Host "   devbox.ps1 (bootstrap installer)..." -ForegroundColor Gray
Copy-Item -Force "dist\devbox.ps1" "$ReleaseDir\devbox.ps1"

Write-Host "   config.psd1 (system configuration)..." -ForegroundColor Gray
Copy-Item -Force "$DevBoxDir\config.psd1" "$ReleaseDir\config.psd1"

Write-Host "   tpl/ (templates directory)..." -ForegroundColor Gray
if (Test-Path "$DevBoxDir\tpl") {
    # Copy entire tpl/ directory, excluding .vscode
    $TplSource = Join-Path $DevBoxDir "tpl"
    $TplDest = Join-Path $ReleaseDir "tpl"

    # Copy recursively, then remove .vscode if present
    Copy-Item -Path $TplSource -Destination $TplDest -Recurse -Force

    # Remove .vscode subdirectories if any
    Get-ChildItem -Path $TplDest -Recurse -Directory -Filter ".vscode" | Remove-Item -Recurse -Force

    # Verify critical templates exist (NO .env.ps1 - it's created directly in .box/)
    $criticalTemplates = @("box.psd1.template", "Makefile.template", "Makefile.amiga.template", "README.template.md")
    foreach ($template in $criticalTemplates) {
        $templatePath = Join-Path $TplDest $template
        if (-not (Test-Path $templatePath)) {
            throw "Release build failed: $template not found in tpl/"
        }
    }
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
Write-Host "   README.md (release version)..." -ForegroundColor Gray
if (Test-Path "$DevBoxDir\tpl\README.release.md") {
    Copy-Item -Force "$DevBoxDir\tpl\README.release.md" "$ReleaseDir\README.md"
} elseif (Test-Path "README.md") {
    # Fallback to main README if release version doesn't exist
    Copy-Item -Force "README.md" "$ReleaseDir\README.md"
}

# Copy install.ps1 if exists
if (Test-Path "$DevBoxDir\install.ps1") {
    Write-Host "   install.ps1..." -ForegroundColor Gray
    Copy-Item -Force "$DevBoxDir\install.ps1" "$ReleaseDir\install.ps1"
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
