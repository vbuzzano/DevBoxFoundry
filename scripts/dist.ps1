<#
.SYNOPSIS
    Distribution build script for DevBoxFoundry releases

.DESCRIPTION
    Orchestrates release build by calling specific release configuration scripts.
    Preserves existing .git repository in dist/release/ directory.

.PARAMETER Release
    Release configuration name (default: amiga)

.EXAMPLE
    .\scripts\dist.ps1 -Release amiga
#>

param(
    [string]$Release = "amiga"
)

$ErrorActionPreference = "Stop"

$VERSION = "0.1.0"
$DIST_DIR = "dist"
$RELEASE_DIR = "$DIST_DIR\release"
$DEVBOX_DIR = "devbox"
$GIT_DIR = "$RELEASE_DIR\.git"
$RELEASE_SCRIPT = "scripts\releases\$Release.ps1"

Write-Host ""
Write-Host "🚀 Building DevBoxFoundry release: $Release v$VERSION" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

try {
    # Step 1: Build box.ps1 (always build before dist)
    Write-Host "🔨 Building box.ps1..." -ForegroundColor Cyan
    Write-Host ""

    $buildScript = "scripts\build-box.ps1"
    if (-not (Test-Path $buildScript)) {
        throw "Build script not found: $buildScript"
    }

    & $buildScript

    if ($LASTEXITCODE -ne 0) {
        throw "Build failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""

    # Step 2: Verify release script exists
    if (-not (Test-Path $RELEASE_SCRIPT)) {
        Write-Host "❌ Error: Release script not found: $RELEASE_SCRIPT" -ForegroundColor Red
        $available = Get-ChildItem scripts\releases\*.ps1 -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName }
        if ($available) {
            Write-Host "Available releases: $($available -join ', ')" -ForegroundColor Yellow
        }
        exit 1
    }

    # Preserve existing .git if present
    $gitBackup = $null
    if (Test-Path $GIT_DIR) {
        Write-Host "📦 Preserving existing .git repository..." -ForegroundColor Yellow
        $gitBackup = Join-Path $env:TEMP "devbox_git_$(Get-Random)"
        Move-Item -Path $GIT_DIR -Destination $gitBackup -Force
        Write-Verbose "  Backed up to: $gitBackup"
    }

    # Clean and recreate release directory
    if (Test-Path $RELEASE_DIR) {
        Write-Host "🧹 Cleaning release directory..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $RELEASE_DIR
    }

    # Create base directories (release only needs root, not inc/tpl)
    Write-Host "📁 Creating directory structure..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $RELEASE_DIR | Out-Null
    Write-Verbose "  Created: $RELEASE_DIR"

    # Restore .git
    if ($gitBackup -and (Test-Path $gitBackup)) {
        Move-Item -Path $gitBackup -Destination $GIT_DIR -Force
        Write-Host "✅ .git repository restored" -ForegroundColor Green
    }

    # Call release-specific configuration script
    Write-Host ""
    Write-Host "⚙️  Executing $Release release configuration..." -ForegroundColor Cyan
    $releaseMetadata = & $RELEASE_SCRIPT -ReleaseDir $RELEASE_DIR -DevBoxDir $DEVBOX_DIR -Version $VERSION

    Write-Host ""
    if ($releaseMetadata) {
        Write-Host "✅ $($releaseMetadata.Name) v$VERSION ready in $RELEASE_DIR" -ForegroundColor Green
    }
    else {
        Write-Host "✅ Release v$VERSION ready in $RELEASE_DIR" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "📌 Next step: .\scripts\release.ps1 -Release $Release" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host ""

    # Cleanup backup if failed
    if ($gitBackup -and (Test-Path $gitBackup)) {
        Remove-Item -Recurse -Force $gitBackup
    }
    exit 1
}
