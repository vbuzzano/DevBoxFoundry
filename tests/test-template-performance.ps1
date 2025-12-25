<#
.SYNOPSIS
    Performance test for template system (Spec 003 Phase 4 T052)

.DESCRIPTION
    Tests that 10 templates can be regenerated in under 2 seconds.

.NOTES
    Run from repository root: .\tests\test-template-performance.ps1
#>

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Template Performance Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create test workspace
$testDir = ".\tests\perf-sandbox"
if (Test-Path $testDir) {
    Remove-Item -Path $testDir -Recurse -Force
}
New-Item -Path $testDir -ItemType Directory -Force | Out-Null
New-Item -Path "$testDir\.box\templates" -ItemType Directory -Force | Out-Null

# Create test .env file
$envContent = @"
PROJECT_NAME=PerfTest
VERSION=1.0.0
AUTHOR=TestUser
DESCRIPTION=Performance Test Project
URL=https://example.com
LICENSE=MIT
COPYRIGHT=2025
MAINTAINER=test@example.com
REPOSITORY=https://github.com/test/repo
BUILDDATE=2025-12-24
"@
Set-Content -Path "$testDir\.env" -Value $envContent -Encoding utf8

# Create 10 test templates
Write-Host "[INFO] Creating 10 test templates..." -ForegroundColor Cyan
for ($i = 1; $i -le 10; $i++) {
    $templateContent = @"
# Template $i
Project: {{PROJECT_NAME}}
Version: {{VERSION}}
Author: {{AUTHOR}}
Description: {{DESCRIPTION}}
URL: {{URL}}
License: {{LICENSE}}
Copyright: {{COPYRIGHT}}
Maintainer: {{MAINTAINER}}
Repository: {{REPOSITORY}}
Build Date: {{BUILDDATE}}

This is template number $i with multiple lines of content.
This helps simulate real-world template processing.
"@
    Set-Content -Path "$testDir\.box\templates\file$i.template" -Value $templateContent -Encoding utf8
}

# Load templates module
. .\devbox\inc\templates.ps1

# Performance test
Write-Host "[TEST] Regenerating 10 templates..." -ForegroundColor Yellow
Push-Location $testDir

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    # Load variables once
    $vars = Merge-TemplateVariables

    # Process all 10 templates
    for ($i = 1; $i -le 10; $i++) {
        $templatePath = ".box\templates\file$i.template"
        $outputPath = "file$i"

        # Read template
        $template = Get-Content $templatePath -Raw -Encoding utf8

        # Process
        $processed = Process-Template -TemplateContent $template -Variables $vars -TemplateName "file$i"

        # Add header
        $header = New-GenerationHeader -FileType 'generic'
        $output = $header + "`n`n" + $processed

        # Write
        Set-Content -Path $outputPath -Value $output -Encoding utf8
    }

    $stopwatch.Stop()
    $elapsed = $stopwatch.Elapsed.TotalSeconds

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Performance Results" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Templates processed: 10" -ForegroundColor White
    Write-Host "Time elapsed: $([math]::Round($elapsed, 3)) seconds" -ForegroundColor White
    Write-Host "Target: < 2.0 seconds" -ForegroundColor Gray
    Write-Host ""

    if ($elapsed -lt 2.0) {
        Write-Host "[OK] Performance test PASSED!" -ForegroundColor Green
        Write-Host "Processing was $([math]::Round((2.0 - $elapsed) / 2.0 * 100, 1))% faster than target" -ForegroundColor Green
        $exitCode = 0
    }
    else {
        Write-Host "[FAIL] Performance test FAILED" -ForegroundColor Red
        Write-Host "Processing was $([math]::Round(($elapsed - 2.0) / 2.0 * 100, 1))% slower than target" -ForegroundColor Red
        $exitCode = 1
    }
}
finally {
    Pop-Location

    # Cleanup
    if (Test-Path $testDir) {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
exit $exitCode
