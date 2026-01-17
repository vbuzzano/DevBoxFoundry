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

# Read version from boxer.version file and auto-increment
$VersionFile = Join-Path $RepoRoot "boxer.version"

# Read current version
if (-not (Test-Path $VersionFile)) {
    throw "boxer.version file not found"
}

$CurrentVersion = (Get-Content $VersionFile -Raw).Trim()
if (-not $CurrentVersion) {
    throw "boxer.version file is empty"
}

# Parse and increment version
if ($CurrentVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $build = [int]$Matches[3]

    # Increment build number
    $build++
    $BoxVersion = "$major.$minor.$build"

    # Save incremented version for this build
    Set-Content -Path $VersionFile -Value $BoxVersion -NoNewline

    Write-Host "Version: $CurrentVersion → $BoxVersion" -ForegroundColor Cyan
} else {
    throw "Invalid version format in boxer.version: $CurrentVersion"
}

Write-Host "`n🔨 Building boxer.ps1" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor DarkGray
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

# Flag indicating this is an embedded/compiled version
`$script:IsEmbedded = `$true

# Embedded version information (injected by build script)
`$script:BoxerVersion = "$BoxVersion"
`$script:BoxName = "$BoxName"
`$script:Mode = 'boxer'

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

# BOXER ONLY: Include only UI functions and version management (shared between boxer and box)
# Workspace-specific files (download, extract, packages, etc.) are NOT needed for boxer
# See: ~ANALYSIS-BOXER-ARCHITECTURE.md for rationale
$coreInclude = @('ui.ps1', 'version.ps1')  # Display and version functions

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
$content += @'

# ============================================================================
# MAIN - Invoke bootstrapper
# ============================================================================

# Ensure Arguments is an array (can be null in irm|iex context)
if (-not $Arguments) { $Arguments = @() }
Initialize-Boxing -Arguments $Arguments

'@

# Write output
$finalContent = ($content -join "`n")

# Replace version placeholders in embedded code
$finalContent = $finalContent -replace '\$script:BoxerVersion = "0\.1\.0"', "`$script:BoxerVersion = `"$BoxVersion`""
$finalContent = $finalContent -replace 'Version: 0\.1\.0', "Version: $BoxVersion"

$finalContent | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host ""
Write-Host "✓ Build complete: $OutputFile" -ForegroundColor Green
Write-Host "  Size: $([math]::Round((Get-Item $OutputFile).Length / 1KB, 2)) KB" -ForegroundColor Gray
Write-Host ""
