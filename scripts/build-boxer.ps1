<#
.SYNOPSIS
    Builds a distributable boxer.ps1

.DESCRIPTION
    Creates a standalone boxer.ps1 that embeds:
    - boxing.ps1 (bootstrapper)
    - core/*.ps1 (shared libraries)
    - modules/boxer/*.ps1 (boxer commands)
    - modules/shared/pkg/*.ps1 (pkg module)

.EXAMPLE
    .\build-boxer.ps1
    Builds to dist/boxer.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputFile = Join-Path $RepoRoot "dist\boxer.ps1"

# Read version from config.psd1
$ConfigPath = Join-Path $RepoRoot "boxers\AmiDevBox\config.psd1"
$BoxVersion = "0.1.0"  # Default fallback
if (Test-Path $ConfigPath) {
    try {
        $config = Import-PowerShellDataFile -Path $ConfigPath
        if ($config.Version) {
            $BoxVersion = $config.Version
        }
    } catch {
        Write-Warning "Could not read version from config.psd1, using default: $BoxVersion"
    }
}

Write-Host "`n🔨 Building boxer.ps1" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host "Version: $BoxVersion" -ForegroundColor Gray
Write-Host ""

# Create dist directory
$distDir = Join-Path $RepoRoot "dist"
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

# Build content
$content = @()

# Header
$content += @"
<#
.SYNOPSIS
    Boxer - Global Boxing Manager

.DESCRIPTION
    Standalone boxer.ps1 with embedded modules

.NOTES
    Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Version: $BoxVersion
#>

param(
    [Parameter(ValueFromRemainingArguments=`$true)]
    [string[]]`$Arguments
)

`$ErrorActionPreference = 'Stop'

# ============================================================================
# EMBEDDED boxing.ps1 (bootstrapper)
# ============================================================================

"@

# Embed boxing.ps1
$boxingPath = Join-Path $RepoRoot "boxing.ps1"
if (Test-Path $boxingPath) {
    $content += "# BEGIN boxing.ps1"
    # Filter out Export-ModuleMember (not valid in compiled script)
    $boxingContent = Get-Content $boxingPath -Raw
    $boxingContent = $boxingContent -replace '(?m)^\s*Export-ModuleMember.*$', '# Export-ModuleMember removed (compiled script)'
    $content += $boxingContent
    $content += "# END boxing.ps1"
    Write-Host "✓ Embedded: boxing.ps1 (functions)" -ForegroundColor Green
}

# Embed core/*.ps1
$content += @"

# ============================================================================
# EMBEDDED core/*.ps1 (shared libraries)
# ============================================================================

"@

# BOXER ONLY: Include only UI functions (shared between boxer and box)
# Workspace-specific files (download, extract, packages, etc.) are NOT needed for boxer
# See: ~ANALYSIS-BOXER-ARCHITECTURE.md for rationale
$coreInclude = @('ui.ps1')  # Only display functions

$coreFiles = Get-ChildItem -Path (Join-Path $RepoRoot "core") -Filter "*.ps1" |
    Where-Object { $_.Name -in $coreInclude } |
    Sort-Object Name

foreach ($file in $coreFiles) {
    $content += "# BEGIN core/$($file.Name)"
    $content += Get-Content $file.FullName -Raw
    $content += "# END core/$($file.Name)"
    Write-Host "✓ Embedded: core/$($file.Name)" -ForegroundColor Green
}

# Embed modules/boxer/*.ps1
$content += @"

# ============================================================================
# EMBEDDED modules/boxer/*.ps1 (boxer commands)
# ============================================================================

"@

$boxerFiles = Get-ChildItem -Path (Join-Path $RepoRoot "modules\boxer") -Filter "*.ps1" | Sort-Object Name
foreach ($file in $boxerFiles) {
    $content += "# BEGIN modules/boxer/$($file.Name)"
    $content += Get-Content $file.FullName -Raw
    $content += "# END modules/boxer/$($file.Name)"
    Write-Host "✓ Embedded: modules/boxer/$($file.Name)" -ForegroundColor Green
}

# NOTE: modules/shared/pkg/*.ps1 NOT embedded in boxer.ps1
# Package management is for box workspaces, not for boxer (box manager)
# See: ~ANALYSIS-BOXER-ARCHITECTURE.md

# Footer - call bootstrapper
$content += @"

# ============================================================================
# MAIN - Invoke bootstrapper
# ============================================================================

Initialize-Boxing -Arguments `$Arguments

"@

# Write output
$finalContent = ($content -join "`n")

# Replace version placeholder in Install-BoxingSystem function
$finalContent = $finalContent -replace '\$NewVersion = "0\.1\.0"  # Will be replaced by build script with actual version', "`$NewVersion = `"$BoxVersion`""

$finalContent | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host ""
Write-Host "✓ Build complete: $OutputFile" -ForegroundColor Green
Write-Host "  Size: $([math]::Round((Get-Item $OutputFile).Length / 1KB, 2)) KB" -ForegroundColor Gray
Write-Host ""
