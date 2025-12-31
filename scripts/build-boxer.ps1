<#
.SYNOPSIS
    Builds a distributable Box package

.DESCRIPTION
    Compiles core modules into box.ps1, copies templates and config files,
    and generates install.ps1 for distribution.

.PARAMETER Box
    Box name to build (default: AmiDevBox)

.EXAMPLE
    .\build-boxer.ps1
    Builds AmiDevBox to dist/AmiDevBox/

.EXAMPLE
    .\build-boxer.ps1 -Box PythonBox
    Builds PythonBox to dist/PythonBox/
#>

[CmdletBinding()]
param(
    [string]$Box = 'AmiDevBox'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$CoreDir = Join-Path $RepoRoot 'core'
$BoxerDir = Join-Path $RepoRoot "boxers\$Box"
$OutputDir = Join-Path $RepoRoot "dist\$Box"

Write-Host "`n🔨 Boxing Build System" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Box: $Box" -ForegroundColor Yellow
Write-Host "  Output: $OutputDir`n" -ForegroundColor Gray

# Validate directories
if (-not (Test-Path $BoxerDir)) {
    Write-Host "✗ ERROR: Box directory not found: $BoxerDir" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $CoreDir)) {
    Write-Host "✗ ERROR: Core directory not found: $CoreDir" -ForegroundColor Red
    exit 1
}

# Create output directory
if (Test-Path $OutputDir) {
    Remove-Item $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Read and compile core modules
Write-Host "📚 Compiling core modules..." -ForegroundColor Yellow
$modules = Get-ChildItem -Path $CoreDir -Filter '*.ps1' | Sort-Object Name
$boxContent = @()

$boxContent += @"
<#
.SYNOPSIS
    Box - Workspace Manager

.DESCRIPTION
    Compiled workspace manager for $Box

.NOTES
    Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Modules: $($modules.Count)
    Box: $Box
#>

`$ErrorActionPreference = 'Stop'

"@

foreach ($module in $modules) {
    Write-Host "   + $($module.Name)" -ForegroundColor Gray
    $boxContent += "# Source: core/$($module.Name)"
    $boxContent += Get-Content $module.FullName -Raw
    $boxContent += "`n"
}

# Write box.ps1
$boxFile = Join-Path $OutputDir 'box.ps1'
$boxContent -join "`n" | Set-Content $boxFile -NoNewline
Write-Host "✓ Created box.ps1 ($($modules.Count) modules)" -ForegroundColor Green

# Copy box files
Write-Host "`n📦 Copying box files..." -ForegroundColor Yellow

# Copy config.psd1
if (Test-Path (Join-Path $BoxerDir 'config.psd1')) {
    Copy-Item (Join-Path $BoxerDir 'config.psd1') $OutputDir
    Write-Host "   + config.psd1" -ForegroundColor Gray
}

# Copy metadata.psd1
if (Test-Path (Join-Path $BoxerDir 'metadata.psd1')) {
    Copy-Item (Join-Path $BoxerDir 'metadata.psd1') $OutputDir
    Write-Host "   + metadata.psd1" -ForegroundColor Gray
}

# Copy templates
if (Test-Path (Join-Path $BoxerDir 'tpl')) {
    Copy-Item (Join-Path $BoxerDir 'tpl') $OutputDir -Recurse
    Write-Host "   + tpl/ (templates)" -ForegroundColor Gray
}

# Copy custom modules if exists
if (Test-Path (Join-Path $BoxerDir 'core')) {
    $customModules = Get-ChildItem (Join-Path $BoxerDir 'core') -Filter '*.ps1'
    if ($customModules.Count -gt 0) {
        Copy-Item (Join-Path $BoxerDir 'core') $OutputDir -Recurse
        Write-Host "   + core/ ($($customModules.Count) custom modules)" -ForegroundColor Gray
    }
}

# Generate install.ps1
Write-Host "`n📝 Generating install.ps1..." -ForegroundColor Yellow

$installScript = @"
<#
.SYNOPSIS
    $Box Installer

.DESCRIPTION
    Installs $Box to Documents\PowerShell\Boxing\Boxes\$Box

.EXAMPLE
    irm https://github.com/vbuzzano/AmiDevBox/raw/main/install.ps1 | iex
#>

`$ErrorActionPreference = 'Stop'

Write-Host "`n🧙 Installing $Box..." -ForegroundColor Cyan

# Installation paths
`$BoxingDir = "`$env:USERPROFILE\Documents\PowerShell\Boxing"
`$BoxesDir = Join-Path `$BoxingDir 'Boxes'
`$BoxDir = Join-Path `$BoxesDir '$Box'

# Create directories
New-Item -ItemType Directory -Path `$BoxDir -Force | Out-Null

# Download and copy files would go here
# (This is a placeholder - actual implementation would download from GitHub)

Write-Host "✓ $Box installed to `$BoxDir" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  boxer init MyProject" -ForegroundColor Cyan
"@

$installFile = Join-Path $OutputDir 'install.ps1'
$installScript | Set-Content $installFile -NoNewline
Write-Host "✓ Generated install.ps1" -ForegroundColor Green

# Summary
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "✓ Build complete!" -ForegroundColor Green
Write-Host "  Output: $OutputDir" -ForegroundColor Gray
Write-Host "  Files:" -ForegroundColor Gray
Get-ChildItem $OutputDir -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($OutputDir.Length + 1)
    Write-Host "    - $relativePath" -ForegroundColor DarkGray
}
Write-Host ""
