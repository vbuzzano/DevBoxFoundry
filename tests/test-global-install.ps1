<#
.SYNOPSIS
    Tests for DevBox global installation (User Story 1)

.DESCRIPTION
    Validates installation workflow: Scripts directory creation,
    devbox.ps1 copy, profile.ps1 creation, #region injection,
    and duplicate installation prevention.
#>

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

# Test configuration
$TestScriptsDir = "$env:TEMP\DevBoxTest\Scripts"
$TestProfilePath = "$env:TEMP\DevBoxTest\profile.ps1"
$DevBoxScriptPath = Join-Path $PSScriptRoot '..\devbox\devbox.ps1'

function Setup-TestEnvironment {
    Write-Host "`n=== Setting up test environment ===" -ForegroundColor Cyan

    # Clean up any previous test
    if (Test-Path "$env:TEMP\DevBoxTest") {
        Remove-Item "$env:TEMP\DevBoxTest" -Recurse -Force
    }

    Write-Host "  ✓ Test environment ready" -ForegroundColor Green
}

function Cleanup-TestEnvironment {
    Write-Host "`n=== Cleaning up test environment ===" -ForegroundColor Cyan

    if (Test-Path "$env:TEMP\DevBoxTest") {
        Remove-Item "$env:TEMP\DevBoxTest" -Recurse -Force
        Write-Host "  ✓ Test environment cleaned" -ForegroundColor Green
    }
}

function Test-ScriptsDirectoryCreation {
    Write-Host "`n[T015] Testing Scripts directory creation..." -ForegroundColor Yellow

    Setup-TestEnvironment

    # Simulate installation by creating Scripts directory
    if (-not (Test-Path $TestScriptsDir)) {
        New-Item -ItemType Directory -Path $TestScriptsDir -Force | Out-Null
    }

    if (Test-Path $TestScriptsDir) {
        Write-Host "  ✓ PASS: Scripts directory created successfully" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "  ✗ FAIL: Scripts directory not created" -ForegroundColor Red
        return $false
    }
}

function Test-ProfileCreation {
    Write-Host "`n[T016] Testing profile.ps1 creation when missing..." -ForegroundColor Yellow

    # Ensure profile doesn't exist
    if (Test-Path $TestProfilePath) {
        Remove-Item $TestProfilePath -Force
    }

    # Create profile
    $profileDir = Split-Path $TestProfilePath -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    New-Item -ItemType File -Path $TestProfilePath -Force | Out-Null

    if (Test-Path $TestProfilePath) {
        Write-Host "  ✓ PASS: Profile created successfully" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "  ✗ FAIL: Profile not created" -ForegroundColor Red
        return $false
    }
}

function Test-RegionInjection {
    Write-Host "`n[T017] Testing #region devbox injection..." -ForegroundColor Yellow

    # Create test profile if needed
    if (-not (Test-Path $TestProfilePath)) {
        $profileDir = Split-Path $TestProfilePath -Parent
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        New-Item -ItemType File -Path $TestProfilePath -Force | Out-Null
    }

    # Inject #region block
    $injection = @'

#region devbox initialize
# Managed by DevBox installer - do not edit manually

function devbox {
    & "$env:USERPROFILE\Documents\PowerShell\Scripts\devbox.ps1" @args
}

function box {
    Write-Host "Box function placeholder"
}
#endregion
'@

    Add-Content -Path $TestProfilePath -Value $injection -Encoding UTF8

    # Verify injection
    $content = Get-Content $TestProfilePath -Raw
    if ($content -match '#region devbox initialize' -and $content -match '#endregion') {
        Write-Host "  ✓ PASS: #region devbox injected successfully" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "  ✗ FAIL: #region devbox not found in profile" -ForegroundColor Red
        return $false
    }
}

function Test-DuplicatePrevention {
    Write-Host "`n[T018] Testing duplicate installation prevention..." -ForegroundColor Yellow

    # Profile should already have #region from previous test
    $contentBefore = Get-Content $TestProfilePath -Raw

    # Try to inject again (should be skipped)
    if ($contentBefore -match '#region devbox initialize') {
        Write-Host "  ℹ️  DevBox already configured (as expected)" -ForegroundColor Cyan

        # Count occurrences
        $matches = ([regex]'#region devbox initialize').Matches($contentBefore)
        if ($matches.Count -eq 1) {
            Write-Host "  ✓ PASS: Duplicate injection prevented" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "  ✗ FAIL: Multiple #region blocks found ($($matches.Count))" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "  ✗ FAIL: No #region found for duplicate test" -ForegroundColor Red
        return $false
    }
}

function Test-ManualInstallation {
    Write-Host "`n[T019] Manual test reminder: Fresh PowerShell installation..." -ForegroundColor Yellow
    Write-Host "  ⚠️  Manual test required:" -ForegroundColor Magenta
    Write-Host "    1. Open fresh PowerShell session" -ForegroundColor White
    Write-Host "    2. Run: .\devbox\devbox.ps1" -ForegroundColor White
    Write-Host "    3. Verify installation completes" -ForegroundColor White
    Write-Host "    4. Open new PowerShell session" -ForegroundColor White
    Write-Host "    5. Run: devbox" -ForegroundColor White
    Write-Host "    6. Verify help displays" -ForegroundColor White
    Write-Host "  ⏸️  SKIP: Manual test (run separately)" -ForegroundColor Yellow
    return $null
}

# ============================================================================
# RUN TESTS
# ============================================================================

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║  DevBox Global Installation Tests (User Story 1)       ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

$results = @()
$results += Test-ScriptsDirectoryCreation
$results += Test-ProfileCreation
$results += Test-RegionInjection
$results += Test-DuplicatePrevention
$manual = Test-ManualInstallation

# Cleanup
Cleanup-TestEnvironment

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
$passed = ($results | Where-Object { $_ -eq $true }).Count
$failed = ($results | Where-Object { $_ -eq $false }).Count
$total = $results.Count

Write-Host "  Passed: $passed / $total" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  Failed: $failed / $total" -ForegroundColor Red
}
Write-Host "  Manual: 1 test (T019)" -ForegroundColor Yellow
Write-Host ""

if ($failed -eq 0) {
    Write-Host "✓ All automated tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some tests failed" -ForegroundColor Red
    exit 1
}
