<#
.SYNOPSIS
Test boxer.ps1 auto-installation (without arguments)
#>

$ErrorActionPreference = 'Stop'

Write-Host "Testing boxer.ps1 auto-installation..." -ForegroundColor Cyan

# Clean test environment
$BoxingDir = "$env:USERPROFILE\Documents\PowerShell\Boxing"
if (Test-Path $BoxingDir) {
    Remove-Item $BoxingDir -Recurse -Force
}

# Execute dist\boxer.ps1 without arguments
$boxerPath = ".\dist\boxer.ps1"
if (-not (Test-Path $boxerPath)) {
    throw "dist\boxer.ps1 not found. Run .\scripts\build-boxer.ps1 first"
}

& $boxerPath  # No arguments = auto-install

# Validate
$tests = @{
    "Boxing directory exists" = Test-Path $BoxingDir
    "boxer.ps1 installed" = Test-Path "$BoxingDir\boxer.ps1"
    "Boxes directory exists" = Test-Path "$BoxingDir\Boxes"
    "Profile modified" = (Get-Content $PROFILE.CurrentUserAllHosts -Raw -ErrorAction SilentlyContinue) -match '#region boxing'
}

$failed = 0
foreach ($test in $tests.GetEnumerator()) {
    if ($test.Value) {
        Write-Host "✓ $($test.Key)" -ForegroundColor Green
    } else {
        Write-Host "✗ $($test.Key)" -ForegroundColor Red
        $failed++
    }
}

if ($failed -eq 0) {
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n$failed test(s) failed!" -ForegroundColor Red
    exit 1
}
