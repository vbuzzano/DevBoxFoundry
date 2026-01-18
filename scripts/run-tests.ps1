<#
.SYNOPSIS
Run Boxing tests

.DESCRIPTION
Execute one or all test files in the tests/ directory.
Supports Pester test files (test-*.ps1).

.PARAMETER Name
Name of the test to run (without 'test-' prefix and '.ps1' extension)
Examples: 'box-update', 'boxer-autoinstall', 'all'

.PARAMETER All
Run all tests

.PARAMETER Detailed
Show detailed output

.EXAMPLE
.\scripts\run-tests.ps1
# Shows available tests

.EXAMPLE
.\scripts\run-tests.ps1 -All
# Run all tests

.EXAMPLE
.\scripts\run-tests.ps1 box-update
# Run test-box-update.ps1

.EXAMPLE
.\scripts\run-tests.ps1 -All -Detailed
# Run all tests with detailed output
#>

param(
    [Parameter(Position = 0)]
    [string]$Name,

    [switch]$All,

    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'

# Get test directory
$TestsDir = Join-Path $PSScriptRoot "..\tests"

if (-not (Test-Path $TestsDir)) {
    Write-Error "Tests directory not found: $TestsDir"
    exit 1
}

# Find all test files
$AllTests = Get-ChildItem -Path $TestsDir -Filter "test-*.ps1" | Where-Object {
    $_.BaseName -match '^test-'
}

if ($AllTests.Count -eq 0) {
    Write-Warning "No test files found in $TestsDir"
    exit 1
}

# Separate Pester tests from legacy tests
$PesterTests = $AllTests | Where-Object {
    (Select-String -Path $_.FullName -Pattern '#Requires -Modules Pester' -Quiet)
}
$LegacyTests = $AllTests | Where-Object {
    -not (Select-String -Path $_.FullName -Pattern '#Requires -Modules Pester' -Quiet)
}

# Show available tests if no parameters
if (-not $Name -and -not $All) {
    Write-Host "`nAvailable tests:" -ForegroundColor Cyan

    if ($PesterTests.Count -gt 0) {
        Write-Host "`n  Pester tests (isolated):" -ForegroundColor Green
        $PesterTests | Sort-Object Name | ForEach-Object {
            $testName = $_.BaseName -replace '^test-', ''
            Write-Host "    • $testName" -ForegroundColor Gray
        }
    }

    if ($LegacyTests.Count -gt 0) {
        Write-Host "`n  Legacy tests:" -ForegroundColor Yellow
        $LegacyTests | Sort-Object Name | ForEach-Object {
            $testName = $_.BaseName -replace '^test-', ''
            Write-Host "    • $testName" -ForegroundColor Gray
        }
    }

    Write-Host "`nUsage:" -ForegroundColor Cyan
    Write-Host "  .\scripts\run-tests.ps1 <test-name>     # Run specific test" -ForegroundColor Gray
    Write-Host "  .\scripts\run-tests.ps1 -All            # Run all tests" -ForegroundColor Gray
    Write-Host "  .\scripts\run-tests.ps1 -All -Detailed  # Run all with details" -ForegroundColor Gray
    exit 0
}

# Prepare output level
$OutputLevel = if ($Detailed) { 'Detailed' } else { 'Normal' }

# Run all tests
if ($All) {
    Write-Host "`nRunning all tests..." -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

    $totalPassed = 0
    $totalFailed = 0

    # Run Pester tests
    if ($PesterTests.Count -gt 0) {
        Write-Host "`n▶ Pester tests ($($PesterTests.Count)):" -ForegroundColor Green

        $config = New-PesterConfiguration
        $config.Run.Path = $PesterTests.FullName
        $config.Output.Verbosity = $OutputLevel
        $config.TestResult.Enabled = $false

        $result = Invoke-Pester -Configuration $config
        if ($result) {
            $totalPassed += $result.PassedCount
            $totalFailed += $result.FailedCount
        }
    }

    # Run legacy tests
    if ($LegacyTests.Count -gt 0) {
        Write-Host "`n▶ Legacy tests ($($LegacyTests.Count)):" -ForegroundColor Yellow

        foreach ($test in $LegacyTests) {
            Write-Host "  Running: $($test.BaseName)..." -ForegroundColor Gray
            try {
                & $test.FullName
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✓ PASS" -ForegroundColor Green
                    $totalPassed++
                } else {
                    Write-Host "    ✗ FAIL (exit code: $LASTEXITCODE)" -ForegroundColor Red
                    $totalFailed++
                }
            } catch {
                Write-Host "    ✗ ERROR: $_" -ForegroundColor Red
                $totalFailed++
            }
        }
    }

    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

    # Only show custom summary if there were legacy tests
    if ($LegacyTests.Count -gt 0) {
        Write-Host "`nSummary:" -ForegroundColor Cyan
        Write-Host "  Total:  $($totalPassed + $totalFailed)" -ForegroundColor Gray
        Write-Host "  Passed: $totalPassed" -ForegroundColor Green
        if ($totalFailed -gt 0) {
            Write-Host "  Failed: $totalFailed" -ForegroundColor Red
        }
    }

    exit $totalFailed
}

# Run specific test
$testFileName = "test-$Name.ps1"
$testFile = $AllTests | Where-Object { $_.Name -eq $testFileName }

if (-not $testFile) {
    Write-Error "Test not found: $testFileName`nAvailable tests: $($AllTests.BaseName -replace '^test-', '' -join ', ')"
    exit 1
}

Write-Host "`nRunning test: $($testFile.BaseName)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

# Check if Pester test
$isPesterTest = $PesterTests | Where-Object { $_.Name -eq $testFile.Name }

if ($isPesterTest) {
    # Run as Pester test
    $config = New-PesterConfiguration
    $config.Run.Path = $testFile.FullName
    $config.Output.Verbosity = $OutputLevel
    $config.TestResult.Enabled = $false

    $result = Invoke-Pester -Configuration $config

    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "`nResult: " -NoNewline -ForegroundColor Cyan
    if ($result -and $result.FailedCount -eq 0) {
        Write-Host "PASS ($($result.PassedCount)/$($result.TotalCount))" -ForegroundColor Green
        exit 0
    } elseif ($result) {
        Write-Host "FAIL ($($result.PassedCount)/$($result.TotalCount))" -ForegroundColor Red
        exit ($result.FailedCount)
    } else {
        Write-Host "ERROR - No result returned" -ForegroundColor Red
        exit 1
    }
} else {
    # Run as legacy test
    Write-Host "  (Legacy test format)" -ForegroundColor Yellow

    try {
        & $testFile.FullName
        $exitCode = $LASTEXITCODE

        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "`nResult: " -NoNewline -ForegroundColor Cyan
        if ($exitCode -eq 0) {
            Write-Host "PASS" -ForegroundColor Green
        } else {
            Write-Host "FAIL (exit code: $exitCode)" -ForegroundColor Red
        }

        exit $exitCode
    } catch {
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "`nResult: " -NoNewline -ForegroundColor Cyan
        Write-Host "ERROR - $_" -ForegroundColor Red
        exit 1
    }
}
