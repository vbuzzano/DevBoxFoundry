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
    $installScript = Join-Path $BoxDir "install.ps1"
    if (Test-Path $installScript) {
        & $installScript
    } else {
        # Inline install
        Create-Directories
        Ensure-SevenZip

        # T035: Try/catch wrapper for continue-on-error (FR-016)
        foreach ($pkg in $AllPackages) {
            try {
                Process-Package $pkg
            } catch {
                Write-Err "Failed to process $($pkg.Name): $_"
                Write-Info "Continuing with remaining packages..."
            }
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

    $uninstallScript = Join-Path $BoxDir "uninstall.ps1"
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

            # T035: Try/catch wrapper for continue-on-error
            foreach ($pkg in $AllPackages) {
                try {
                    Process-Package $pkg
                } catch {
                    Write-Err "Failed to process $($pkg.Name): $_"
                    Write-Info "Continuing with remaining packages..."
                }
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

    # Verbose info
    if ($VerbosePreference -eq 'Continue') {
        Write-Verbose "Template directory: .box/templates/"
        Write-Verbose "Variable sources: .env, box.config.psd1"
    }

    # Load template variables
    $variables = Merge-TemplateVariables

    if ($VerbosePreference -eq 'Continue' -and $variables.Count -gt 0) {
        Write-Verbose "Loaded $($variables.Count) variables:"
        foreach ($key in ($variables.Keys | Sort-Object)) {
            Write-Verbose "  $key = $($variables[$key])"
        }
    }

    if ($variables.Count -eq 0) {
        Write-Host "  [WARN] No variables found in .env or box.config.psd1" -ForegroundColor Yellow
    }

    # Get available templates
    $templates = Get-AvailableTemplates -TemplateDir '.box/templates'

    if ($templates.Count -eq 0) {
        Write-Host "  [INFO] No templates found in .box/templates/" -ForegroundColor Cyan
        return
    }

    $successCount = 0
    $failCount = 0

    foreach ($template in $templates) {
        $outputPath = $template

        # Find the actual template file - search for *.template and *.template.*
        # Pattern: For "README.md", search for "README.template.md" or "README.template"
        # Pattern: For "Makefile", search for "Makefile.template" or "Makefile.template.*"

        $actualTemplate = $null

        # Try: output_name.template (e.g., Makefile.template)
        if (Test-Path ".box/templates/$template.template" -PathType Leaf) {
            $actualTemplate = Get-Item ".box/templates/$template.template"
        }
        else {
            # Try: output_name_without_ext.template.ext (e.g., README.template.md)
            $templateWithExt = ".box/templates/$($template -split '\.' | Select-Object -First 1).template.$($template -split '\.' | Select-Object -Last 1)"
            if (Test-Path $templateWithExt -PathType Leaf) {
                $actualTemplate = Get-Item $templateWithExt
            }
        }

        if (-not $actualTemplate) {
            Write-Host "  [!] Template file not found for: $template" -ForegroundColor Yellow
            $failCount++
            continue
        }
        $templatePath = $actualTemplate.FullName

        Write-Host "  [*] Processing: $template..." -ForegroundColor White

        if ($VerbosePreference -eq 'Continue') {
            Write-Verbose "Template file: $templatePath"
            Write-Verbose "Output file: $outputPath"
        }

        try {
            # Validate file size
            if (-not (Test-TemplateFileSize -FilePath $templatePath)) {
                $failCount++
                continue
            }

            # Validate encoding
            if (-not (Test-FileEncoding -FilePath $templatePath)) {
                Write-Host "    [WARN] Template may not be UTF-8 encoded: $template" -ForegroundColor Yellow
            }

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
                    Write-Host "    [BKP] Backed up: $(Split-Path $backupPath -Leaf)" -ForegroundColor Gray
                    if ($VerbosePreference -eq 'Continue') {
                        Write-Verbose "Backup created: $backupPath"
                    }
                }
            }

            # Write generated file
            Set-Content -Path $outputPath -Value $output -Encoding UTF8 -Force
            Write-Host "    [OK] Generated: $outputPath" -ForegroundColor Green
            if ($VerbosePreference -eq 'Continue') {
                Write-Verbose "Written $($output.Length) characters to $outputPath"
            }
            $successCount++
        }
        catch {
            Write-Host "    [ERR] Error: $_" -ForegroundColor Red
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

    if ($VerbosePreference -eq 'Continue') {
        Write-Verbose "Template name: $Template"
    }

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
        Write-Host "  [ERR] Template not found: $Template" -ForegroundColor Red
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

        if ($VerbosePreference -eq 'Continue') {
            Write-Verbose "Loaded $($variables.Count) variables from .env and config"
            Write-Verbose "Template path: $templatePath"
            Write-Verbose "Output path: $outputPath"
        }

        # Validate file size
        if (-not (Test-TemplateFileSize -FilePath $templatePath)) {
            exit 1
        }

        # Validate encoding
        if (-not (Test-FileEncoding -FilePath $templatePath)) {
            Write-Host "  [WARN] Template may not be UTF-8 encoded" -ForegroundColor Yellow
        }

        # Read template
        $content = Get-Content $templatePath -Raw -Encoding UTF8

        # Process tokens
        Write-Host "  [*] Processing template..." -ForegroundColor White
        $processed = Process-Template -TemplateContent $content -Variables $variables -TemplateName $Template

        # Add generation header
        $fileType = if ($outputPath -like '*.md') { 'markdown' } elseif ($outputPath -like 'Makefile*') { 'makefile' } else { 'generic' }
        $header = New-GenerationHeader -FileType $fileType
        $output = $header + "`n`n" + $processed

        # Backup existing file if exists
        if (Test-Path $outputPath) {
            $backupPath = Backup-File -FilePath $outputPath
            if ($backupPath) {
                Write-Host "  [BKP] Backed up: $(Split-Path $backupPath -Leaf)" -ForegroundColor Gray
            }
        }

        # Write generated file
        Set-Content -Path $outputPath -Value $output -Encoding UTF8 -Force
        Write-Host "  [OK] Generated: $outputPath" -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERR] Error: $_" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
}
