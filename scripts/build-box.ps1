<#
.SYNOPSIS
    Compiles modular DevBox sources into a single distributable box.ps1

.DESCRIPTION
    This script reads all PowerShell modules from devbox/inc/ and the main
    app.ps1, then concatenates them into a single dist/box.ps1 file for
    distribution. This enables modular development with single-file deployment.

.PARAMETER Verbose
    Show detailed compilation steps

.EXAMPLE
    .\build-box.ps1
    Compiles devbox sources into dist/box.ps1

.NOTES
    Feature: 001-compilation-system
    User Story: US1 - Basic Module Compilation
#>

[CmdletBinding()]
param()

# Configuration
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceDir = Join-Path $RepoRoot 'devbox'
$ModulesDir = Join-Path $SourceDir 'inc'
$MainScript = Join-Path $SourceDir 'app.ps1'
$OutputDir = Join-Path $RepoRoot 'dist'
$OutputFile = Join-Path $OutputDir 'box.ps1'

Write-Host "`n🔨 DevBox Compilation System" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor DarkGray

# Auto-increment patch version (X.Y.N)
$DevBoxScript = Join-Path $SourceDir 'devbox.ps1'
$currentVersion = "0.1.0"  # fallback
if (Test-Path $DevBoxScript) {
    Write-Host "🔢 Auto-incrementing version..." -ForegroundColor Yellow
    $content = Get-Content $DevBoxScript -Raw
    if ($content -match "\`$Script:DevBoxVersion\s*=\s*'((\d+)\.(\d+)\.(\d+))'") {
        $currentVersion = $matches[1]
        $major = [int]$matches[2]
        $minor = [int]$matches[3]
        $patch = [int]$matches[4]
        $newPatch = $patch + 1
        $newVersion = "$major.$minor.$newPatch"

        $content = $content -replace "(\`$Script:DevBoxVersion\s*=\s*)'[\d.]+'" , "`$1'$newVersion'"
        Set-Content -Path $DevBoxScript -Value $content -NoNewline

        Write-Host "   $currentVersion → $newVersion" -ForegroundColor Gray
        $currentVersion = $newVersion
    }
}

# Validate source files exist
if (-not (Test-Path $ModulesDir)) {
    Write-Host "✗ ERROR: Modules directory not found: $ModulesDir" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $MainScript)) {
    Write-Host "✗ ERROR: Main script not found: $MainScript" -ForegroundColor Red
    exit 1
}

# Read all module files
Write-Host "📚 Reading source modules..." -ForegroundColor Yellow
$moduleFiles = Get-ChildItem -Path $ModulesDir -Filter '*.ps1' | Sort-Object Name
$moduleCount = $moduleFiles.Count

if ($moduleCount -eq 0) {
    Write-Host "✗ ERROR: No .ps1 modules found in $ModulesDir" -ForegroundColor Red
    exit 1
}

Write-Verbose "  Found $moduleCount modules in $ModulesDir"

# Build content array
$compiledContent = @()

# Add header
$compiledContent += @"
<#
.SYNOPSIS
    DevBox - Unified Development Workspace Manager

.DESCRIPTION
    Compiled from modular sources by build-box.ps1

.NOTES
    Compilation Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Source Modules: $moduleCount
    Build System: Feature 001 - Compilation System
#>

"@

# Read main application script first
Write-Host "📄 Reading main application script..." -ForegroundColor Yellow
Write-Verbose "  Reading: app.ps1"
$appLines = Get-Content -Path $MainScript

# Find line indices for strategic replacement
$initStartIndex = -1
$initEndIndex = -1

for ($i = 0; $i -lt $appLines.Count; $i++) {
    if ($appLines[$i] -match '^\$_initPath = Join-Path') {
        $initStartIndex = $i
    }
    if ($initStartIndex -ge 0 -and $appLines[$i] -match '^\. \$_initPath') {
        $initEndIndex = $i
        break
    }
}

if ($initStartIndex -ge 0 -and $initEndIndex -ge 0) {
    Write-Verbose "  Found init.ps1 loading block at lines $initStartIndex-$initEndIndex"

    # Build compiled content: app header + modules + app footer

    # Part 1: Everything before init loading
    $compiledContent += ($appLines[0..($initStartIndex - 1)] -join "`n")
    $compiledContent += "`n"

    # Part 2: Inject modules
    $compiledContent += "`n# ══════════════════════════════════════════════════════════════════════════════"
    $compiledContent += "# COMPILED MODULES (injected by build-box.ps1 - replaces init.ps1 loading)"
    $compiledContent += "# ══════════════════════════════════════════════════════════════════════════════`n"

    foreach ($module in $moduleFiles) {
        Write-Verbose "  Reading: $($module.Name)"
        $content = Get-Content -Path $module.FullName -Raw -ErrorAction Stop

        # Clean dot-source commands (US4: Clean Output)
        $content = $content -replace '(?m)^\s*\.\s+"?\$script:IncDir\\[^"]+\.ps1"?\s*$', ''

        # Remove functions.ps1 loading block from init.ps1 (already compiled in)
        $content = $content -replace '(?ms)^\$script:FunctionsLoader = Join-Path.*?\. \$FunctionsLoader\s*$', ''

        # Add source mapping (US2: Source Mapping)
        $compiledContent += "# ──────────────────────────────────────────────────────────────────────────────"
        $compiledContent += "# Source: inc/$($module.Name)"
        $compiledContent += "# ──────────────────────────────────────────────────────────────────────────────"
        $compiledContent += $content
        $compiledContent += "`n"
    }

    $compiledContent += "# ══════════════════════════════════════════════════════════════════════════════"
    $compiledContent += "# END COMPILED MODULES"
    $compiledContent += "# ══════════════════════════════════════════════════════════════════════════════`n"
    $compiledContent += "`n# Main Application (source: app.ps1)"
    $compiledContent += "`$script:SkipExecution = `$false`n"

    # Part 3: Everything after init loading
    if ($initEndIndex + 1 -lt $appLines.Count) {
        $compiledContent += ($appLines[($initEndIndex + 1)..($appLines.Count - 1)] -join "`n")
    }

} else {
    Write-Host "⚠ Warning: Could not find init.ps1 loading block" -ForegroundColor Yellow
    Write-Host "  Using simple concatenation" -ForegroundColor Yellow
    $compiledContent += ($appLines -join "`n")
}

# Create output directory if missing
if (-not (Test-Path $OutputDir)) {
    Write-Verbose "  Creating output directory: $OutputDir"
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

# Write compiled output
Write-Host "💾 Writing compiled output..." -ForegroundColor Yellow
$finalContent = $compiledContent -join "`n"

# Inject version into compiled box.ps1
$finalContent = $finalContent -replace "(\`$Script:BoxVersion\s*=\s*if\s*\(\`$Script:DevBoxVersion\)\s*\{\s*\`$Script:DevBoxVersion\s*\}\s*else\s*\{\s*)[^\}]+", "`$1'$currentVersion'"

Set-Content -Path $OutputFile -Value $finalContent -Encoding UTF8 -NoNewline -ErrorAction Stop

# Copy bootstrap installer to dist
Write-Host "📋 Copying bootstrap installer..." -ForegroundColor Yellow
$BootstrapSource = Join-Path $SourceDir 'devbox.ps1'
$BootstrapDest = Join-Path $OutputDir 'devbox.ps1'
if (Test-Path $BootstrapSource) {
    Copy-Item -Path $BootstrapSource -Destination $BootstrapDest -Force
    Write-Verbose "  Copied: devbox.ps1 to dist/"
}

# Copy templates directory
$TplSource = Join-Path $SourceDir 'tpl'
$TplDest = Join-Path $OutputDir 'tpl'
if (Test-Path $TplSource) {
    if (Test-Path $TplDest) {
        Remove-Item -Recurse -Force $TplDest
    }
    Copy-Item -Path $TplSource -Destination $TplDest -Recurse -Force
    Write-Verbose "  Copied: tpl/ to dist/"
}

# Verify output
if (Test-Path $OutputFile) {
    $outputSize = (Get-Item $OutputFile).Length
    $outputSizeKB = [math]::Round($outputSize / 1KB, 2)

    Write-Host "`n✅ Compilation successful!" -ForegroundColor Green
    Write-Host "   Output: $OutputFile" -ForegroundColor Gray
    Write-Host "   Size: $outputSizeKB KB" -ForegroundColor Gray
    Write-Host "   Modules: $moduleCount" -ForegroundColor Gray

    # Quick syntax validation
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize($finalContent, [ref]$null)
        Write-Host "   Syntax: ✓ Valid PowerShell" -ForegroundColor Gray
    }
    catch {
        Write-Host "   Syntax: ⚠ Warning - Syntax errors detected" -ForegroundColor Yellow
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    exit 0
}
else {
    Write-Host "`n✗ FAILURE: Output file not created" -ForegroundColor Red
    exit 1
}
