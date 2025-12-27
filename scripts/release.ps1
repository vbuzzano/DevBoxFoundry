<#
.SYNOPSIS
    Syncs and pushes dist/release/ to release repository

.DESCRIPTION
    Clones or pulls the release repository (e.g., AmiDevBox), copies files from
    dist/release/, commits, and pushes. Always stays in sync with remote.
    Reads configuration from .vscode/settings.json.

.PARAMETER Release
    Release configuration name (default: amiga)

.PARAMETER Message
    Commit message (default: auto-generated with timestamp)

.EXAMPLE
    .\scripts\release.ps1 -Release amiga -Message "Release v1.0.0"
#>

param(
    [string]$Release = "amiga",
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"

$RELEASE_DIR = "dist\release"
$TEMP_CLONE = Join-Path $env:TEMP "devbox-release-$(Get-Random)"

Write-Host ""
Write-Host "🚀 Releasing $Release..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

try {
    # Verify dist/release exists
    if (-not (Test-Path $RELEASE_DIR)) {
        Write-Host "❌ Error: $RELEASE_DIR not found" -ForegroundColor Red
        Write-Host "   Run '.\scripts\dist.ps1' first to build the release" -ForegroundColor Yellow
        exit 1
    }

    # Get release metadata from .vscode/settings.json
    $settingsPath = ".vscode\settings.json"
    $releaseName = $Release
    $releaseRepo = $null

    if (Test-Path $settingsPath) {
        Write-Host "📋 Reading release configuration..." -ForegroundColor Yellow
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

        if ($settings.PSObject.Properties.Name -contains "devbox.releases") {
            $releases = $settings."devbox.releases"
            if ($releases.PSObject.Properties.Name -contains $Release) {
                $releaseConfig = $releases.$Release
                $releaseName = $releaseConfig.name
                $releaseRepo = $releaseConfig.repository
                Write-Host "   Name: $releaseName" -ForegroundColor Gray
                Write-Host "   Repo: $releaseRepo" -ForegroundColor Gray
            }
            else {
                Write-Host "❌ Error: Release '$Release' not found in settings" -ForegroundColor Red
                $available = $releases.PSObject.Properties.Name -join ', '
                Write-Host "   Available: $available" -ForegroundColor Yellow
                exit 1
            }
        }
        else {
            Write-Host "❌ Error: No releases configured in settings.json" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "❌ Error: .vscode/settings.json not found" -ForegroundColor Red
        exit 1
    }

    if (-not $releaseRepo) {
        Write-Host "❌ Error: Repository URL not configured for '$Release'" -ForegroundColor Red
        exit 1
    }

    # Clone repository to temporary location
    Write-Host ""
    Write-Host "📥 Cloning $releaseName repository..." -ForegroundColor Cyan
    git clone $releaseRepo $TEMP_CLONE 2>&1 | ForEach-Object {
        if ($_ -match "error|fatal") {
            Write-Host "   $_" -ForegroundColor Red
        } else {
            Write-Host "   $_" -ForegroundColor DarkGray
        }
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Git clone failed with exit code $LASTEXITCODE"
    }

    # Copy files from dist/release to cloned repo (excluding .git)
    Write-Host ""
    Write-Host "📋 Copying release files..." -ForegroundColor Yellow
    Get-ChildItem -Path $RELEASE_DIR -Exclude ".git" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $TEMP_CLONE -Recurse -Force
        Write-Host "   ✓ $($_.Name)" -ForegroundColor DarkGray
    }

    # Enter cloned repo and commit
    Push-Location $TEMP_CLONE

    # Check for changes
    Write-Host ""
    Write-Host "📝 Checking for changes..." -ForegroundColor Yellow
    $status = git status --porcelain

    if ($status) {
        Write-Host "   Changes detected:" -ForegroundColor Gray
        $status -split "`n" | Select-Object -First 10 | ForEach-Object { Write-Host "   $_" -ForegroundColor DarkGray }
        if (($status -split "`n").Count -gt 10) {
            Write-Host "   ... and $(($status -split "`n").Count - 10) more files" -ForegroundColor DarkGray
        }

        Write-Host ""
        Write-Host "💾 Committing changes..." -ForegroundColor Cyan

        $commitMessage = if ($Message) {
            $Message
        } else {
            "Release $releaseName - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        }

        git add -A
        git commit -m $commitMessage
        Write-Host "   ✅ Committed: $commitMessage" -ForegroundColor Green

        # Push to origin
        Write-Host ""
        Write-Host "📤 Pushing to $releaseName repository..." -ForegroundColor Cyan
        git push origin main 2>&1 | ForEach-Object {
            if ($_ -match "error|fatal") {
                Write-Host "   $_" -ForegroundColor Red
            } else {
                Write-Host "   $_" -ForegroundColor Gray
            }
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Git push failed with exit code $LASTEXITCODE"
        }

        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "✅ Release pushed successfully to $releaseName" -ForegroundColor Green
        Write-Host ""
    }
    else {
        Write-Host "   No changes to push" -ForegroundColor Gray
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "✅ Repository already up to date" -ForegroundColor Green
        Write-Host ""
    }

    Pop-Location

    # Cleanup temporary clone
    Write-Host "🧹 Cleaning up..." -ForegroundColor DarkGray
    Remove-Item -Recurse -Force $TEMP_CLONE
}
catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host ""
    Pop-Location -ErrorAction SilentlyContinue

    # Cleanup on error
    if (Test-Path $TEMP_CLONE) {
        Remove-Item -Recurse -Force $TEMP_CLONE -ErrorAction SilentlyContinue
    }

    exit 1
}
