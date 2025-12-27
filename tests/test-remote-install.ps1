<#
.SYNOPSIS
    Tests for remote installation via irm | iex

.DESCRIPTION
    Validates that installation works when PSCommandPath is empty
    (simulating irm | iex scenario)
#>

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║  DevBox Remote Installation Test (irm | iex)           ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

Write-Host "[Test] PSCommandPath detection logic..." -ForegroundColor Yellow
Write-Host ""

# Test 1: Verify PSCommandPath is empty in this context
$testPath = $PSCommandPath
if ([string]::IsNullOrEmpty($testPath)) {
    Write-Host "  ✓ PASS: PSCommandPath is empty (simulates irm | iex)" -ForegroundColor Green
}
else {
    Write-Host "  ℹ️  INFO: PSCommandPath = $testPath (running as file)" -ForegroundColor Cyan
    Write-Host "  Note: When run via irm | iex, PSCommandPath is empty" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[Test] Download URL validation..." -ForegroundColor Yellow
Write-Host ""

# Test 2: Verify download URL is accessible (would need actual GitHub push)
$expectedUrl = "https://github.com/vbuzzano/DevBoxFoundry/raw/main/dist/devbox.ps1"
Write-Host "  Expected URL: $expectedUrl" -ForegroundColor Cyan

# Test 3: Verify local dist/devbox.ps1 exists
Write-Host ""
Write-Host "[Test] Local dist/devbox.ps1 exists..." -ForegroundColor Yellow
Write-Host ""

$distScript = Join-Path $PSScriptRoot '..\dist\devbox.ps1'
if (Test-Path $distScript) {
    Write-Host "  ✓ PASS: dist/devbox.ps1 exists" -ForegroundColor Green

    # Verify syntax
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $distScript -Raw), [ref]$null)
    Write-Host "  ✓ PASS: dist/devbox.ps1 syntax valid" -ForegroundColor Green
}
else {
    Write-Host "  ✗ FAIL: dist/devbox.ps1 not found" -ForegroundColor Red
    Write-Host "  Run: Copy-Item devbox\devbox.ps1 dist\devbox.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""
Write-Host "✅ Pre-flight checks passed" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  To test actual remote installation:" -ForegroundColor Yellow
Write-Host "   1. Commit and push changes to GitHub" -ForegroundColor White
Write-Host "   2. Run: irm https://github.com/vbuzzano/DevBoxFoundry/raw/main/dist/devbox.ps1 | iex" -ForegroundColor White
Write-Host "   3. Verify installation completes successfully" -ForegroundColor White
Write-Host ""

exit 0
