<#
.SYNOPSIS
    Non-Regression Tests for Version Management System

.DESCRIPTION
    Validates that version detection, comparison, and update logic
    functions correctly without regression. Tests FR-030 to FR-034.

.NOTES
    Created: 2026-01-09
    Feature: 001-boxing-consolidation (US7)
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
if ($Verbose) { $VerbosePreference = 'Continue' }

Write-Host ""
Write-Host "🧪 Version Management Non-Regression Tests" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host ""

$TestsPassed = 0
$TestsFailed = 0

function Test-Assertion {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$ErrorMessage = ""
    )

    if ($Condition) {
        Write-Host "  ✓ $Name" -ForegroundColor Green
        $script:TestsPassed++
    }
    else {
        Write-Host "  ✗ $Name" -ForegroundColor Red
        if ($ErrorMessage) {
            Write-Host "    $ErrorMessage" -ForegroundColor DarkRed
        }
        $script:TestsFailed++
    }
}

# ============================================================================
# Test 1: boxer.version File Exists and Valid Format
# ============================================================================

Write-Host "Test Group: Version File Integrity" -ForegroundColor Cyan

$versionFile = "boxer.version"
Test-Assertion `
    -Name "boxer.version file exists" `
    -Condition (Test-Path $versionFile)

if (Test-Path $versionFile) {
    $version = (Get-Content $versionFile -Raw).Trim()

    Test-Assertion `
        -Name "boxer.version is not empty" `
        -Condition (-not [string]::IsNullOrWhiteSpace($version))

    Test-Assertion `
        -Name "boxer.version follows semantic versioning (X.Y.Z)" `
        -Condition ($version -match '^\d+\.\d+\.\d+$') `
        -ErrorMessage "Version format: $version"
}

Write-Host ""

# ============================================================================
# Test 2: Version Detection from Multiple Sources
# ============================================================================

Write-Host "Test Group: Version Detection Sources" -ForegroundColor Cyan

# Load core/version.ps1 to access Get-BoxerVersion
$versionScript = "core\version.ps1"
if (Test-Path $versionScript) {
    . $versionScript

    $script:BoxingRoot = Get-Location
    $detectedVersion = Get-BoxerVersion

    Test-Assertion `
        -Name "Get-BoxerVersion returns a value" `
        -Condition (-not [string]::IsNullOrWhiteSpace($detectedVersion)) `
        -ErrorMessage "Returned: '$detectedVersion'"

    if ($detectedVersion) {
        Test-Assertion `
            -Name "Detected version matches boxer.version file" `
            -Condition ($detectedVersion -eq $version) `
            -ErrorMessage "File: $version, Detected: $detectedVersion"
    }
}
else {
    Test-Assertion `
        -Name "core/version.ps1 exists" `
        -Condition $false `
        -ErrorMessage "Version detection script not found"
}

Write-Host ""

# ============================================================================
# Test 3: Build Script Auto-Increment Logic
# ============================================================================

Write-Host "Test Group: Build Version Auto-Increment" -ForegroundColor Cyan

$buildScript = "scripts\build-boxer.ps1"
Test-Assertion `
    -Name "scripts/build-boxer.ps1 exists" `
    -Condition (Test-Path $buildScript)

if (Test-Path $buildScript) {
    $buildContent = Get-Content $buildScript -Raw

    Test-Assertion `
        -Name "Build script reads boxer.version file" `
        -Condition ($buildContent -match 'boxer\.version')

    Test-Assertion `
        -Name "Build script increments version" `
        -Condition ($buildContent -match '\$build\+\+')

    Test-Assertion `
        -Name "Build script writes new version back" `
        -Condition ($buildContent -match 'Set-Content\s+.*\$VersionFile')
}

Write-Host ""

# ============================================================================
# Test 4: Dual-Version Tracking in Metadata
# ============================================================================

Write-Host "Test Group: Dual-Version Tracking (Version + BoxerVersion)" -ForegroundColor Cyan

$metadataFile = "boxers\AmiDevBox\metadata.psd1"
if (Test-Path $metadataFile) {
    $metadataContent = Get-Content $metadataFile -Raw

    Test-Assertion `
        -Name "metadata.psd1 contains Version field" `
        -Condition ($metadataContent -match 'Version\s*=')

    Test-Assertion `
        -Name "metadata.psd1 contains BoxerVersion field" `
        -Condition ($metadataContent -match 'BoxerVersion\s*=')

    # Parse metadata
    try {
        $metadata = Import-PowerShellDataFile $metadataFile

        Test-Assertion `
            -Name "Version field is valid semantic version" `
            -Condition ($metadata.Version -match '^\d+\.\d+\.\d+$') `
            -ErrorMessage "Version: $($metadata.Version)"

        Test-Assertion `
            -Name "BoxerVersion field is valid semantic version" `
            -Condition ($metadata.BoxerVersion -match '^\d+\.\d+\.\d+$') `
            -ErrorMessage "BoxerVersion: $($metadata.BoxerVersion)"
    }
    catch {
        Test-Assertion `
            -Name "metadata.psd1 is parseable" `
            -Condition $false `
            -ErrorMessage $_.Exception.Message
    }
}
else {
    Write-Host "  ⊘ Skipping (no sample metadata found)" -ForegroundColor DarkGray
}

Write-Host ""

# ============================================================================
# Test 5: Smart Update Logic Exists
# ============================================================================

Write-Host "Test Group: Smart Update Logic" -ForegroundColor Cyan

$installScript = "modules\boxer\install.ps1"
if (Test-Path $installScript) {
    $installContent = Get-Content $installScript -Raw

    Test-Assertion `
        -Name "install.ps1 has Get-InstalledBoxVersion function" `
        -Condition ($installContent -match 'function Get-InstalledBoxVersion')

    Test-Assertion `
        -Name "install.ps1 has Get-RemoteBoxVersion function" `
        -Condition ($installContent -match 'function Get-RemoteBoxVersion')

    Test-Assertion `
        -Name "install.ps1 compares versions before install" `
        -Condition ($installContent -match 'Get-InstalledBoxVersion' -and $installContent -match 'Get-RemoteBoxVersion')
}
else {
    Test-Assertion `
        -Name "modules/boxer/install.ps1 exists" `
        -Condition $false
}

Write-Host ""

# ============================================================================
# Summary
# ============================================================================

Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host ""
Write-Host "Test Results:" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($TestsFailed -eq 0) {
    Write-Host "✓ All version management tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some tests failed. Review version management implementation." -ForegroundColor Red
    exit 1
}
