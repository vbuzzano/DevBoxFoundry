# ============================================================================
# Command Functions (Invoke-*)
# ============================================================================

function Invoke-Install {
    # Run wizard if config doesn't exist
    if ($NeedsWizard) {
        if (-not (Invoke-ConfigWizard)) {
            return
        }
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  $($Config.Project.Name) Setup" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    
    # Run install script if exists
    $installScript = Join-Path $SetupDir "install.ps1"
    if (Test-Path $installScript) {
        & $installScript
    } else {
        # Inline install
        Create-Directories
        Ensure-SevenZip
        
        foreach ($pkg in $AllPackages) {
            Process-Package $pkg
        }
        
        Cleanup-Temp
        Setup-Makefile
        Generate-AllEnvFiles
        
        Show-InstallComplete
    }
}

function Invoke-Uninstall {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  Uninstall Environment" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    $uninstallScript = Join-Path $SetupDir "uninstall.ps1"
    if (Test-Path $uninstallScript) {
        & $uninstallScript
    } else {
        Do-Uninstall
    }
}

function Invoke-Env {
    param([string]$Sub, [string[]]$Params)
    
    switch ($Sub) {
        "list" {
            Show-EnvList
        }
        "update" {
            Generate-AllEnvFiles
            Write-Host "[OK] .env updated" -ForegroundColor Green
        }
        default {
            Write-Host "Unknown env subcommand: $Sub" -ForegroundColor Red
            Write-Host "Use: list, update" -ForegroundColor Gray
            exit 1
        }
    }
}

function Invoke-Pkg {
    param([string]$Sub)
    
    switch ($Sub) {
        "list" {
            Show-PackageList
        }
        "update" {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "  Update Packages" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            
            Ensure-SevenZip
            
            foreach ($pkg in $AllPackages) {
                Process-Package $pkg
            }
            
            # Only update env files, not Makefile
            Generate-AllEnvFiles
            
            Write-Host ""
            Write-Host "[OK] Packages updated" -ForegroundColor Green
        }
        default {
            Write-Host " Unknown pkg subcommand: $Sub" -ForegroundColor Red
            Write-Host "Use: list, update" -ForegroundColor Gray
            exit 1
        }
    }
}

# ============================================================================
# Template Commands
# ============================================================================

function Invoke-EnvUpdate {
    <#
    .SYNOPSIS
        Regenerate all template files from current environment

    .DESCRIPTION
        Regenerates Makefile, README.md and other template-based files
        using current values from .env and box.config.psd1.

    .EXAMPLE
        box env update
    #>

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Updating Templates" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # Load template variables
    $variables = Merge-TemplateVariables

    if ($variables.Count -eq 0) {
        Write-Host "  ⚠ No variables found in .env or box.config.psd1" -ForegroundColor Yellow
    }

    # Get available templates
    $templates = Get-AvailableTemplates -TemplateDir '.box/templates'

    if ($templates.Count -eq 0) {
        Write-Host "  ℹ No templates found in .box/templates/" -ForegroundColor Cyan
        return
    }

    $successCount = 0
    $failCount = 0

    foreach ($template in $templates) {
        $templatePath = ".box/templates/$template.template"
        $outputPath = $template

        Write-Host "  ⏳ Processing: $template..." -ForegroundColor White

        try {
            # Read template
            $content = Get-Content $templatePath -Raw -Encoding UTF8

            # Process tokens
            $processed = Process-Template -TemplateContent $content -Variables $variables -TemplateName $template

            # Add generation header based on file type
            $fileType = if ($template -like '*.md') { 'markdown' } elseif ($template -eq 'Makefile*') { 'makefile' } else { 'generic' }
            $header = New-GenerationHeader -FileType $fileType
            $output = $header + "`n`n" + $processed

            # Backup existing file if exists
            if (Test-Path $outputPath) {
                $backupPath = Backup-File -FilePath $outputPath
                if ($backupPath) {
                    Write-Host "    💾 Backed up: $(Split-Path $backupPath -Leaf)" -ForegroundColor Gray
                }
            }

            # Write generated file
            Set-Content -Path $outputPath -Value $output -Encoding UTF8 -Force
            Write-Host "    ✓ Generated: $outputPath" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "    ❌ Error: $_" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host ""
    Write-Host "Summary: $successCount generated" -ForegroundColor Green
    if ($failCount -gt 0) {
        Write-Host "         $failCount failed" -ForegroundColor Red
    }
}

function Invoke-TemplateApply {
    <#
    .SYNOPSIS
        Regenerate a single template file

    .DESCRIPTION
        Regenerates one specific template-based file using current
        environment values.

    .PARAMETER Template
        Template name to apply (e.g., 'Makefile', 'README.md')

    .EXAMPLE
        box template apply Makefile
    #>
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Template
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Applying Template: $Template" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # Normalize template name (add .template if missing)
    if (-not $Template.EndsWith('.template')) {
        $templatePath = ".box/templates/$Template.template"
        $outputPath = $Template
    }
    else {
        $templatePath = ".box/templates/$Template"
        $outputPath = $Template -replace '\.template$', ''
    }

    # Check if template exists
    if (-not (Test-Path $templatePath)) {
        $available = Get-AvailableTemplates -TemplateDir '.box/templates'
        Write-Host "  ❌ Template not found: $Template" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available templates:" -ForegroundColor Yellow
        foreach ($t in $available) {
            Write-Host "  - $t" -ForegroundColor White
        }
        exit 1
    }

    try {
        # Load template variables
        $variables = Merge-TemplateVariables

        # Read template
        $content = Get-Content $templatePath -Raw -Encoding UTF8

        # Process tokens
        Write-Host "  ⏳ Processing template..." -ForegroundColor White
        $processed = Process-Template -TemplateContent $content -Variables $variables -TemplateName $Template

        # Add generation header
        $fileType = if ($outputPath -like '*.md') { 'markdown' } elseif ($outputPath -like 'Makefile*') { 'makefile' } else { 'generic' }
        $header = New-GenerationHeader -FileType $fileType
        $output = $header + "`n`n" + $processed

        # Backup existing file if exists
        if (Test-Path $outputPath) {
            $backupPath = Backup-File -FilePath $outputPath
            if ($backupPath) {
                Write-Host "  💾 Backed up: $(Split-Path $backupPath -Leaf)" -ForegroundColor Gray
            }
        }

        # Write generated file
        Set-Content -Path $outputPath -Value $output -Encoding UTF8 -Force
        Write-Host "  ✓ Generated: $outputPath" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Error: $_" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
}
