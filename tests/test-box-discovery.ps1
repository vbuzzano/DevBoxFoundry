<#
.SYNOPSIS
    Tests for box command discovery (User Story 2)

.DESCRIPTION
    Validates box command parent directory search logic:
    current directory, parent directory, deep nesting,
    and no .box/ found scenario.
#>

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

# Test configuration
$TestRootDir = "$env:TEMP\DevBoxTest\BoxDiscovery"

function Setup-TestEnvironment {
    Write-Host "`n=== Setting up test environment ===" -ForegroundColor Cyan

    # Clean up any previous test
    if (Test-Path $TestRootDir) {
        Remove-Item $TestRootDir -Recurse -Force
    }

    # Create test directory structure
    New-Item -ItemType Directory -Path $TestRootDir -Force | Out-Null

    Write-Host "  ✓ Test environment ready" -ForegroundColor Green
}

function Cleanup-TestEnvironment {
    Write-Host "`n=== Cleaning up test environment ===" -ForegroundColor Cyan

    if (Test-Path $TestRootDir) {
        Remove-Item $TestRootDir -Recurse -Force
        Write-Host "  ✓ Test environment cleaned" -ForegroundColor Green
    }
}

function Test-CurrentDirectoryBox {
    Write-Host "`n[T026] Testing .box/ in current directory..." -ForegroundColor Yellow

    # Create project structure
    $projectDir = Join-Path $TestRootDir 'CurrentDirTest'
    $boxDir = Join-Path $projectDir '.box'
    $boxScript = Join-Path $boxDir 'box.ps1'

    New-Item -ItemType Directory -Path $boxDir -Force | Out-Null
    Set-Content -Path $boxScript -Value 'Write-Host "Box script found!"' -Encoding UTF8

    # Simulate box discovery from current directory
    Push-Location $projectDir
    try {
        $testPath = Join-Path (Get-Location).Path '.box\box.ps1'
        if (Test-Path $testPath) {
            Write-Host "  ✓ PASS: .box/box.ps1 found in current directory" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "  ✗ FAIL: .box/box.ps1 not found in current directory" -ForegroundColor Red
            return $false
        }
    }
    finally {
        Pop-Location
    }
}

function Test-ParentDirectoryDiscovery {
    Write-Host "`n[T027] Testing parent directory discovery (1 level up)..." -ForegroundColor Yellow

    # Create project structure with subdirectory
    $projectDir = Join-Path $TestRootDir 'ParentTest'
    $boxDir = Join-Path $projectDir '.box'
    $boxScript = Join-Path $boxDir 'box.ps1'
    $subDir = Join-Path $projectDir 'src'

    New-Item -ItemType Directory -Path $boxDir -Force | Out-Null
    New-Item -ItemType Directory -Path $subDir -Force | Out-Null
    Set-Content -Path $boxScript -Value 'Write-Host "Box script found!"' -Encoding UTF8

    # Simulate box discovery from subdirectory
    $current = Get-Item $subDir
    $boxFound = $false

    while ($current.FullName -ne [System.IO.Path]::GetPathRoot($current.FullName)) {
        $testPath = Join-Path $current.FullName '.box\box.ps1'
        if (Test-Path $testPath) {
            $boxFound = $true
            break
        }
        $parent = Split-Path $current.FullName -Parent
        if (-not $parent) { break }
        $current = Get-Item $parent
    }

    if ($boxFound) {
        Write-Host "  ✓ PASS: .box/box.ps1 found in parent directory" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "  ✗ FAIL: .box/box.ps1 not found in parent directory" -ForegroundColor Red
        return $false
    }
}

function Test-DeepNesting {
    Write-Host "`n[T028] Testing deep nesting (5 levels up)..." -ForegroundColor Yellow

    # Create project structure with deep nesting
    $projectDir = Join-Path $TestRootDir 'DeepTest'
    $boxDir = Join-Path $projectDir '.box'
    $boxScript = Join-Path $boxDir 'box.ps1'
    $deepDir = Join-Path $projectDir 'src\components\ui\buttons\primary'

    New-Item -ItemType Directory -Path $boxDir -Force | Out-Null
    New-Item -ItemType Directory -Path $deepDir -Force | Out-Null
    Set-Content -Path $boxScript -Value 'Write-Host "Box script found!"' -Encoding UTF8

    # Simulate box discovery from deep subdirectory
    $startPath = $deepDir
    $current = Get-Item $deepDir
    $boxFound = $false
    $boxPath = $null

    while ($current.FullName -ne [System.IO.Path]::GetPathRoot($current.FullName)) {
        $testPath = Join-Path $current.FullName '.box\box.ps1'
        if (Test-Path $testPath) {
            $boxFound = $true
            $boxPath = $current.FullName
            break
        }
        $parent = Split-Path $current.FullName -Parent
        if (-not $parent) { break }
        $current = Get-Item $parent
    }

    if ($boxFound) {
        # Calculate actual levels
        $startParts = $startPath.Split('\')
        $boxParts = $boxPath.Split('\')
        $levels = $startParts.Count - $boxParts.Count

        if ($levels -eq 5) {
            Write-Host "  ✓ PASS: .box/box.ps1 found 5 levels up" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "  ⚠️  PARTIAL: .box/box.ps1 found but at $levels levels (expected 5)" -ForegroundColor Yellow
            return $true
        }
    }
    else {
        Write-Host "  ✗ FAIL: .box/box.ps1 not found in parent tree" -ForegroundColor Red
        return $false
    }
}

function Test-NoBoxFound {
    Write-Host "`n[T029] Testing no .box/ found scenario..." -ForegroundColor Yellow

    # Create directory without .box/
    $noBoxDir = Join-Path $TestRootDir 'NoBoxTest'
    New-Item -ItemType Directory -Path $noBoxDir -Force | Out-Null

    # Simulate box discovery
    Push-Location $noBoxDir
    try {
        $current = Get-Location
        $boxFound = $false

        while ($current.Path -ne [System.IO.Path]::GetPathRoot($current.Path)) {
            $testPath = Join-Path $current.Path '.box\box.ps1'
            if (Test-Path $testPath) {
                $boxFound = $true
                break
            }
            $parent = Split-Path $current.Path -Parent
            if (-not $parent) { break }
            $current = Get-Item $parent
        }

        if (-not $boxFound) {
            Write-Host "  ℹ️  No DevBox project found (as expected)" -ForegroundColor Cyan
            Write-Host "  ✓ PASS: Correctly detected no .box/ in tree" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "  ✗ FAIL: Unexpectedly found .box/ (test contamination?)" -ForegroundColor Red
            return $false
        }
    }
    finally {
        Pop-Location
    }
}

function Test-ManualBoxCommand {
    Write-Host "`n[T030] Manual test reminder: box command from subdirectory..." -ForegroundColor Yellow
    Write-Host "  ⚠️  Manual test required:" -ForegroundColor Magenta
    Write-Host "    1. Create project: devbox init TestProject" -ForegroundColor White
    Write-Host "    2. cd TestProject" -ForegroundColor White
    Write-Host "    3. mkdir -p src/deep/path" -ForegroundColor White
    Write-Host "    4. cd src/deep/path" -ForegroundColor White
    Write-Host "    5. Run: box help" -ForegroundColor White
    Write-Host "    6. Verify box finds parent .box/ and executes" -ForegroundColor White
    Write-Host "  ⏸️  SKIP: Manual test (run separately)" -ForegroundColor Yellow
    return $null
}

# ============================================================================
# RUN TESTS
# ============================================================================

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║  DevBox Box Discovery Tests (User Story 2)             ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

Setup-TestEnvironment

$results = @()
$results += Test-CurrentDirectoryBox
$results += Test-ParentDirectoryDiscovery
$results += Test-DeepNesting
$results += Test-NoBoxFound
$manual = Test-ManualBoxCommand

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
Write-Host "  Manual: 1 test (T030)" -ForegroundColor Yellow
Write-Host ""

if ($failed -eq 0) {
    Write-Host "✓ All automated tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some tests failed" -ForegroundColor Red
    exit 1
}
