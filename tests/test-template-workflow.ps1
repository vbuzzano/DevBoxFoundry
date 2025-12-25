<#
.SYNOPSIS
    Workflow integration tests for template system (Spec 003 Phase 4)

.DESCRIPTION
    Tests complete workflows:
    - T048: Full workflow (init → env update → verify)
    - T049: Custom template modification
    - T050: Special characters handling
    - T051: Backup restoration

.NOTES
    Run from repository root: .\tests\test-template-workflow.ps1
#>

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Template Workflow Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-Workflow {
    param(
        [string]$Name,
        [scriptblock]$Test
    )

    Write-Host "[TEST] $Name" -ForegroundColor Yellow
    try {
        $result = & $Test
        if ($result -eq $true -or $result -eq "PASS") {
            Write-Host "  [OK] PASS" -ForegroundColor Green
            $script:testsPassed++
        }
        else {
            Write-Host "  [FAIL] $result" -ForegroundColor Red
            $script:testsFailed++
        }
    }
    catch {
        Write-Host "  [FAIL] Error: $_" -ForegroundColor Red
        $script:testsFailed++
    }
    Write-Host ""
}

# Create test workspace
$testDir = ".\tests\workflow-sandbox"
if (Test-Path $testDir) {
    Remove-Item -Path $testDir -Recurse -Force
}
New-Item -Path $testDir -ItemType Directory -Force | Out-Null
New-Item -Path "$testDir\.box\templates" -ItemType Directory -Force | Out-Null

# ============================================================================
# T048: Complete workflow test
# ============================================================================

Test-Workflow -Name "T048: Complete workflow - init → env update → verify" -Test {
    # 1. Create test .env file
    $envContent = @"
PROJECT_NAME=WorkflowTest
PROJECT_VERSION=1.0.0
AUTHOR=TestUser
"@
    Set-Content -Path "$testDir\.env" -Value $envContent -Encoding utf8

    # 2. Create test config
    $configContent = @"
@{
    DESCRIPTION = "Test Project"
}
"@
    Set-Content -Path "$testDir\box.config.psd1" -Value $configContent -Encoding utf8

    # 3. Create test template
    $templateContent = @"
# Project: {{PROJECT_NAME}}
Version: {{PROJECT_VERSION}}
Author: {{AUTHOR}}
Description: {{DESCRIPTION}}
"@
    Set-Content -Path "$testDir\.box\templates\README.template.md" -Value $templateContent -Encoding utf8

    # 4. Load templates module
    . .\devbox\inc\templates.ps1

    # 5. Generate from template
    Push-Location $testDir
    try {
        $vars = Merge-TemplateVariables
        $template = Get-Content ".box\templates\README.template.md" -Raw -Encoding utf8
        $processed = Process-Template -TemplateContent $template -Variables $vars -TemplateName "README.md"
        $header = New-GenerationHeader -FileType 'markdown'
        $output = $header + "`n`n" + $processed
        Set-Content -Path "README.md" -Value $output -Encoding utf8

        # 6. Verify output
        $result = Get-Content "README.md" -Raw -Encoding utf8

        if ($result -like "*WorkflowTest*" -and 
            $result -like "*1.0.0*" -and 
            $result -like "*TestUser*" -and 
            $result -like "*Test Project*") {
            return $true
        }
        return "Generated content missing expected values"
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# T049: Custom template modification
# ============================================================================

Test-Workflow -Name "T049: Custom template modification and regeneration" -Test {
    Push-Location $testDir
    try {
        # 1. Modify template
        $modifiedTemplate = @"
# Modified Template
Project: {{PROJECT_NAME}} v{{PROJECT_VERSION}}
Custom field: {{AUTHOR}}
"@
        Set-Content -Path ".box\templates\README.template.md" -Value $modifiedTemplate -Encoding utf8

        # 2. Regenerate
        . ..\..\devbox\inc\templates.ps1
        $vars = Merge-TemplateVariables
        $template = Get-Content ".box\templates\README.template.md" -Raw -Encoding utf8
        $processed = Process-Template -TemplateContent $template -Variables $vars -TemplateName "README.md"
        $header = New-GenerationHeader -FileType 'markdown'
        $output = $header + "`n`n" + $processed
        Set-Content -Path "README.md" -Value $output -Encoding utf8 -Force

        # 3. Verify new content
        $result = Get-Content "README.md" -Raw -Encoding utf8

        if ($result -like "*Modified Template*" -and 
            $result -like "*Custom field: TestUser*") {
            return $true
        }
        return "Modified template not reflected in output"
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# T050: Special characters in token values
# ============================================================================

Test-Workflow -Name "T050: Special characters handling in values" -Test {
    Push-Location $testDir
    try {
        # 1. Create .env with special chars (use single quotes to preserve literals)
        $specialEnv = 'PROJECT_PATH=C:\Users\Test$Special.Path
PROJECT_URL=https://example.com/repo?query=value&other=123
PROJECT_REGEX=^[a-z]+$'
        Set-Content -Path ".env" -Value $specialEnv -Encoding utf8

        # 2. Create template with these tokens
        $specialTemplate = @"
Path: {{PROJECT_PATH}}
URL: {{PROJECT_URL}}
Regex: {{PROJECT_REGEX}}
"@
        Set-Content -Path ".box\templates\special.template" -Value $specialTemplate -Encoding utf8

        # 3. Process
        . ..\..\devbox\inc\templates.ps1
        $vars = Get-TemplateVariables -EnvPath ".env"
        $template = Get-Content ".box\templates\special.template" -Raw -Encoding utf8
        $processed = Process-Template -TemplateContent $template -Variables $vars -TemplateName "special"

        # 4. Verify special chars are preserved (use -match for literal matching)
        $hasPath = $processed -match [regex]::Escape('C:\Users\Test$Special.Path')
        $hasURL = $processed -like '*https://example.com/repo?query=value&other=123*'
        $hasRegex = $processed -match [regex]::Escape('^[a-z]+$')
        
        if ($hasPath -and $hasURL -and $hasRegex) {
            return $true
        }
        return "Special characters not properly handled: Path=$hasPath, URL=$hasURL, Regex=$hasRegex"
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# T051: Backup restoration validation
# ============================================================================

Test-Workflow -Name "T051: Backup file can be restored" -Test {
    Push-Location $testDir
    try {
        # 1. Create initial file
        $initialContent = "Original content v1.0"
        Set-Content -Path "test-file.txt" -Value $initialContent -Encoding utf8

        # 2. Create backup
        . ..\..\devbox\inc\templates.ps1
        $backupPath = Backup-File -FilePath "test-file.txt"

        if (-not $backupPath) {
            return "Backup creation failed"
        }

        # 3. Modify original
        Set-Content -Path "test-file.txt" -Value "Modified content v2.0" -Encoding utf8

        # 4. Verify backup has original content
        $backupContent = Get-Content $backupPath -Raw -Encoding utf8

        if ($backupContent -notlike "*Original content v1.0*") {
            return "Backup does not contain original content"
        }

        # 5. Test restoration
        Copy-Item -Path $backupPath -Destination "test-file.txt" -Force
        $restoredContent = Get-Content "test-file.txt" -Raw -Encoding utf8

        if ($restoredContent -like "*Original content v1.0*") {
            return $true
        }
        return "Restoration failed"
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# Cleanup and Summary
# ============================================================================

if (Test-Path $testDir) {
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Workflow Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor Red
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "[OK] All workflow tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "[FAIL] Some workflow tests failed" -ForegroundColor Red
    exit 1
}
