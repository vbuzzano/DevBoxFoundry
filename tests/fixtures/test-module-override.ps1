# ============================================================================
# Test: Box Module Override Mechanism
# ============================================================================
#
# Tests that box-specific modules in .box/modules/ override core modules

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$FixturePath = Join-Path $PSScriptRoot "override-example"

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Box Module Override Test" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

# Test 1: Verify override module exists
Write-Host "Test 1: Override module exists" -ForegroundColor Yellow
$overrideModulePath = Join-Path $FixturePath ".box\modules\install.ps1"
if (Test-Path $overrideModulePath) {
    Write-Host "  ✓ PASS: Override module found at $overrideModulePath" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: Override module not found" -ForegroundColor Red
    exit 1
}

# Test 2: Verify boxing.ps1 supports box override priority
Write-Host ""
Write-Host "Test 2: boxing.ps1 has override priority logic" -ForegroundColor Yellow
$boxingPath = Join-Path $RepoRoot "boxing.ps1"
$boxingContent = Get-Content $boxingPath -Raw
if ($boxingContent -match 'box-override') {
    Write-Host "  ✓ PASS: boxing.ps1 contains box-override priority" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: boxing.ps1 missing override logic" -ForegroundColor Red
    exit 1
}

# Test 3: Verify override module has correct function name
Write-Host ""
Write-Host "Test 3: Override module has correct function signature" -ForegroundColor Yellow
$overrideContent = Get-Content $overrideModulePath -Raw
if ($overrideContent -match 'function Invoke-Box-Install') {
    Write-Host "  ✓ PASS: Override module has Invoke-Box-Install function" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: Override module missing Invoke-Box-Install" -ForegroundColor Red
    exit 1
}

# Test 4: Execute override in isolation (mock test)
Write-Host ""
Write-Host "Test 4: Override module execution (isolated)" -ForegroundColor Yellow
try {
    # Dot-source the override module
    . $overrideModulePath

    # Call function and check it exists
    $functionExists = Get-Command -Name Invoke-Box-Install -ErrorAction SilentlyContinue

    if ($functionExists) {
        Write-Host "  ✓ PASS: Override module loaded successfully" -ForegroundColor Green

        # Execute to verify no errors
        Invoke-Box-Install -Arguments @("test-package") | Out-Null
        Write-Host "  ✓ PASS: Override module executes without errors" -ForegroundColor Green
    } else {
        Write-Host "  ✗ FAIL: Override module function not found" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ✗ FAIL: Override module execution failed: $_" -ForegroundColor Red
    exit 1
}

# Test 5: Verify verbose logging indicates source
Write-Host ""
Write-Host "Test 5: Verbose logging shows module source" -ForegroundColor Yellow
if ($boxingContent -match 'Write-Verbose.*\$source') {
    Write-Host "  ✓ PASS: Verbose logging includes source variable" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: Verbose logging missing source indication" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "All tests passed! ✓" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""
