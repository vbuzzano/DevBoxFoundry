<#
.SYNOPSIS
    Commits and pushes dist/release/ to release repository

.DESCRIPTION
    Commits changes in dist/release/ directory and pushes to the configured
    release repository (e.g., AmiDevBox). Reads configuration from .vscode/settings.json.

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
    $releaseRepo = "origin"

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
                Write-Host "   ⚠️  Release '$Release' not found in settings, using defaults" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "   ⚠️  No releases configured in settings, using defaults" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "   ⚠️  .vscode/settings.json not found, using defaults" -ForegroundColor Yellow
    }

    # Verify .git exists in dist/release
    if (-not (Test-Path "$RELEASE_DIR\.git")) {
        Write-Host ""
        Write-Host "🔧 Initializing git repository in $RELEASE_DIR..." -ForegroundColor Cyan
        Push-Location $RELEASE_DIR
        git init
        git branch -M main
        git remote add origin $releaseRepo
        Pop-Location
        Write-Host "   ✅ Git initialized" -ForegroundColor Green
    }

    # Enter release directory and commit
    Push-Location $RELEASE_DIR

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
    }
    else {
        Write-Host "   No changes to commit" -ForegroundColor Gray
    }

    # Push to origin
    Write-Host ""
    Write-Host "📤 Pushing to $releaseName repository..." -ForegroundColor Cyan
    git push -u origin main 2>&1 | ForEach-Object {
        if ($_ -match "error|fatal") {
            Write-Host "   $_" -ForegroundColor Red
        } else {
            Write-Host "   $_" -ForegroundColor Gray
        }
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "✅ Release pushed successfully to $releaseName" -ForegroundColor Green
        Write-Host ""
    } else {
        throw "Git push failed with exit code $LASTEXITCODE"
    }

    Pop-Location
}
catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host ""
    Pop-Location -ErrorAction SilentlyContinue
    exit 1
}
