<#
.SYNOPSIS
Test boxer.ps1 web installation (simulating irm | iex)
#>

$ErrorActionPreference = 'Stop'

Write-Host "Testing boxer.ps1 web installation (simulating irm|iex)..." -ForegroundColor Cyan

# Clean test environment
$BoxingDir = "$env:USERPROFILE\Documents\PowerShell\Boxing"
if (Test-Path $BoxingDir) {
    Remove-Item $BoxingDir -Recurse -Force
}

# Simulate irm|iex by executing script content without PSCommandPath
$boxerContent = Get-Content ".\dist\boxer.ps1" -Raw

# Execute in a new scope to simulate irm|iex (no $PSCommandPath)
& {
    param($scriptContent)
    Invoke-Expression $scriptContent
} -scriptContent $boxerContent

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
