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

$DIST_DIR = "dist"
$RELEASE_DIR = "$DIST_DIR\release"
$DEVBOX_DIR = "devbox"
$GIT_DIR = "$RELEASE_DIR\.git"
$RELEASE_SCRIPT = "scripts\releases\$Release.ps1"

Write-Host ""
Write-Host "🚀 Building DevBoxFoundry release: $Release v" -ForegroundColor Cyan -NoNewline
if (Test-Path "boxer.version") {
    $BoxerVersion = (Get-Content "boxer.version" -Raw).Trim()
    Write-Host $BoxerVersion -ForegroundColor Cyan
} else {
    Write-Host ""
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

try {
    # Step 1: Build boxer.ps1 (increment version)
    Write-Host "🔨 Building boxer.ps1..." -ForegroundColor Cyan
    Write-Host ""

    $buildBoxerScript = "scripts\build-boxer.ps1"
    if (-not (Test-Path $buildBoxerScript)) {
        throw "Build script not found: $buildBoxerScript"
    }

    & $buildBoxerScript

    if (-not (Test-Path "dist\boxer.ps1")) {
        throw "Build failed: dist\boxer.ps1 not created"
    }

    # Extract and increment boxer version for next build
    $BoxerContent = Get-Content "dist\boxer.ps1" -Raw
    if ($BoxerContent -match 'Version:\s*(\d+\.\d+\.\d+)') {
        $currentBoxerVersion = $Matches[1]

        # Increment build number
        if ($currentBoxerVersion -match '(\d+)\.(\d+)\.(\d+)') {
            $major = $Matches[1]
            $minor = $Matches[2]
            $build = [int]$Matches[3]
            $build++
            $nextBoxerVersion = "$major.$minor.$build"

            # Save incremented version for next build
            Set-Content -Path "boxer.version" -Value $nextBoxerVersion -NoNewline -Encoding UTF8
            Write-Host "   Boxer version incremented: $currentBoxerVersion → $nextBoxerVersion (for next build)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""

    # Step 2: Build box.ps1 (always build before dist)
    Write-Host "🔨 Building box.ps1..." -ForegroundColor Cyan
    Write-Host ""

    $buildBoxScript = "scripts\build-box.ps1"
    if (-not (Test-Path $buildBoxScript)) {
        throw "Build script not found: $buildBoxScript"
    }

    & $buildBoxScript

    if (-not (Test-Path "dist\box.ps1")) {
        throw "Build failed: dist\box.ps1 not created"
    }

    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""

    # Step 3: Verify release script exists
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

    # Preserve existing metadata.psd1 to track version increments
    $metadataBackup = $null
    $metadataFile = Join-Path $RELEASE_DIR "metadata.psd1"
    if (Test-Path $metadataFile) {
        Write-Host "📦 Preserving existing metadata.psd1..." -ForegroundColor Yellow
        $metadataBackup = Join-Path $env:TEMP "devbox_metadata_$(Get-Random).psd1"
        Copy-Item -Path $metadataFile -Destination $metadataBackup -Force
        Write-Verbose "  Backed up to: $metadataBackup"
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

    # Restore metadata.psd1 temporarily for version tracking
    if ($metadataBackup -and (Test-Path $metadataBackup)) {
        Copy-Item -Path $metadataBackup -Destination $metadataFile -Force
        Write-Verbose "  Metadata backup restored for version tracking"
    }

    # Extract boxer version from dist/boxer.ps1
    $BoxerVersion = "0.1.0"
    if (Test-Path "dist\boxer.ps1") {
        $BoxerContent = Get-Content "dist\boxer.ps1" -Raw
        if ($BoxerContent -match 'Version:\s*(\d+\.\d+\.\d+)') {
            $BoxerVersion = $Matches[1]
        }
    }

    # Call release-specific configuration script
    Write-Host ""
    Write-Host "⚙️  Executing $Release release configuration..." -ForegroundColor Cyan
    $releaseMetadata = & $RELEASE_SCRIPT -ReleaseDir $RELEASE_DIR -DevBoxDir $DEVBOX_DIR -BoxerVersion $BoxerVersion

    # Cleanup metadata backup
    if ($metadataBackup -and (Test-Path $metadataBackup)) {
        Remove-Item -Force $metadataBackup -ErrorAction SilentlyContinue
    }

    Write-Host ""
    if ($releaseMetadata) {
        Write-Host "✅ $($releaseMetadata.Name) v$($releaseMetadata.Version) (core $BoxerVersion) ready in $RELEASE_DIR" -ForegroundColor Green
    }
    else {
        Write-Host "✅ Release ready in $RELEASE_DIR" -ForegroundColor Green
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
