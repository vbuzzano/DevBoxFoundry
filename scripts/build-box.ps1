<#
.SYNOPSIS
    Builds a distributable box.ps1

.DESCRIPTION
    Creates a standalone box.ps1 that embeds:
    - boxing.ps1 (bootstrapper)
    - core/*.ps1 (shared libraries)
    - modules/box/*.ps1 (box commands)
    - modules/shared/pkg/*.ps1 (pkg module)

.EXAMPLE
    .\build-box.ps1
    Builds to dist/box.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputFile = Join-Path $RepoRoot "dist\box.ps1"

Write-Host "`n🔨 Building box.ps1" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host ""

# Create dist directory
$distDir = Join-Path $RepoRoot "dist"
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

# Read box version from AmiDevBox metadata (fallback to boxer build)
$BoxVersion = $null
$amiMetadataPath = Join-Path $RepoRoot "boxers\AmiDevBox\metadata.psd1"
if (Test-Path $amiMetadataPath) {
    try {
        $amiMetadata = Import-PowerShellDataFile $amiMetadataPath
        if ($amiMetadata.Version) {
            $BoxVersion = $amiMetadata.Version
        }
    } catch {
        Write-Host "[WARN] Failed to read AmiDevBox metadata version: $_" -ForegroundColor Yellow
    }
}

# Fallback: derive from boxer.ps1 if metadata unavailable
if (-not $BoxVersion) {
    $BoxVersion = "1.0.0"
    if (Test-Path "dist\boxer.ps1") {
        $boxerContent = Get-Content "dist\boxer.ps1" -Raw -ErrorAction SilentlyContinue
        if ($boxerContent -match 'Version:\s*(\d+\.\d+\.\d+)') {
            $BoxVersion = $Matches[1]
        }
    }
}

# Build content
$content = @()

# Header
$content += @"
<#
.SYNOPSIS
    Box - Project Workspace Manager

.DESCRIPTION
    Standalone box.ps1 with embedded modules

.NOTES
    Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Version: $BoxVersion
#>

param(
    [Parameter(Position=0)]
    [string]`$Command,

    [Parameter(ValueFromRemainingArguments=`$true)]
    [string[]]`$Arguments
)

`$ErrorActionPreference = 'Stop'

# ============================================================================
# Bootstrap - Find .box directory
# ============================================================================

# Embedded version information (injected by build script)
`$script:BoxerVersion = "$BoxVersion"

`$BaseDir = Get-Location
`$BoxDir = `$null

while (`$true) {
    `$testPath = Join-Path `$BaseDir '.box'
    if (Test-Path `$testPath) {
        `$BoxDir = `$testPath
        break
    }
    `$parent = Split-Path `$BaseDir -Parent
    if (-not `$parent -or `$parent -eq `$BaseDir) {
        Write-Host "ERROR: No .box directory found" -ForegroundColor Red
        Write-Host "Run this from a box project directory" -ForegroundColor Gray
        exit 1
    }
    `$BaseDir = `$parent
}

# Set global paths
`$script:BaseDir = `$BaseDir
`$script:BoxDir = `$BoxDir
`$script:VendorDir = Join-Path `$BaseDir "vendor"
`$script:TempDir = Join-Path `$BaseDir "temp"
`$script:StateFile = Join-Path `$BoxDir "state.json"

# ============================================================================
# EMBEDDED boxing.ps1 (bootstrapper functions)
# ============================================================================

"@

# Embed boxing.ps1 (only the functions, not the execution)
$boxingPath = Join-Path $RepoRoot "boxing.ps1"
if (Test-Path $boxingPath) {
    $boxingContent = Get-Content $boxingPath -Raw
    # Extract only function definitions, skip execution code
    $content += "# BEGIN boxing.ps1 (functions only)"
    $content += $boxingContent -replace '(?s)# Call main.*$', ''
    $content += "# END boxing.ps1"
    Write-Host "✓ Embedded: boxing.ps1 (functions)" -ForegroundColor Green
}

# Embed core/*.ps1
$content += @"

# ============================================================================
# EMBEDDED core/*.ps1 (shared libraries)
# ============================================================================

"@

$coreFiles = Get-ChildItem -Path (Join-Path $RepoRoot "core") -Filter "*.ps1" | Sort-Object Name
foreach ($file in $coreFiles) {
    $content += "# BEGIN core/$($file.Name)"
    $content += Get-Content $file.FullName -Raw
    $content += "# END core/$($file.Name)"
    Write-Host "✓ Embedded: core/$($file.Name)" -ForegroundColor Green
}

# Embed modules/box/*.ps1 (including subdirectories)
$content += @"

# ============================================================================
# EMBEDDED modules/box/*.ps1 (box commands)
# ============================================================================

"@

$boxFiles = Get-ChildItem -Path (Join-Path $RepoRoot "modules\box") -Filter "*.ps1" -Recurse | Sort-Object FullName
foreach ($file in $boxFiles) {
    $relativePath = $file.FullName.Substring((Join-Path $RepoRoot "modules\box").Length + 1)
    $content += "# BEGIN modules/box/$relativePath"
    $content += Get-Content $file.FullName -Raw
    $content += "# END modules/box/$relativePath"
    Write-Host "✓ Embedded: modules/box/$relativePath" -ForegroundColor Green
}

# Embed modules/shared/pkg/*.ps1
$content += @"

# ============================================================================
# EMBEDDED modules/shared/pkg/*.ps1 (pkg module)
# ============================================================================

"@

$pkgFiles = Get-ChildItem -Path (Join-Path $RepoRoot "modules\shared\pkg") -Filter "*.ps1" | Sort-Object Name
foreach ($file in $pkgFiles) {
    $content += "# BEGIN modules/shared/pkg/$($file.Name)"
    $content += Get-Content $file.FullName -Raw
    $content += "# END modules/shared/pkg/$($file.Name)"
    Write-Host "✓ Embedded: modules/shared/pkg/$($file.Name)" -ForegroundColor Green
}

# Footer - Use Initialize-Boxing dispatcher (like boxer.ps1)
$content += @"

# ============================================================================
# MAIN - Call Initialize-Boxing (Spec 010 architecture)
# ============================================================================

# Set embedded flag and mode before calling Initialize-Boxing
`$script:IsEmbedded = `$true
`$script:Mode = 'box'

# Build arguments array (Command + remaining Arguments)
`$allArgs = @()
if (`$Command) {
    `$allArgs += `$Command
}
if (`$Arguments) {
    `$allArgs += `$Arguments
}

# Call main bootstrapper with all arguments
Initialize-Boxing -Arguments `$allArgs

"@

# Write output
$content -join "`n" | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host ""
Write-Host "✓ Build complete: $OutputFile" -ForegroundColor Green
Write-Host "  Size: $([math]::Round((Get-Item $OutputFile).Length / 1KB, 2)) KB" -ForegroundColor Gray
Write-Host ""
