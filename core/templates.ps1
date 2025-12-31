<#
.SYNOPSIS
    Template processor module for DevBox

.DESCRIPTION
    Provides functions to load variables, process templates with token replacement,
    manage backups, and apply template-based file generation.

.NOTES
    Module: templates.ps1
    Version: 0.1.0
#>

# ============================================================================
# TEMPLATE VARIABLE FUNCTIONS
# ============================================================================

function Get-TemplateVariables {
    <#
    .SYNOPSIS
        Load environment variables from .env file into hashtable

    .DESCRIPTION
        Reads .env file and parses key=value pairs into hashtable for use in
        template token replacement.

    .PARAMETER EnvPath
        Path to .env file. Defaults to .env in current directory.

    .OUTPUTS
        [hashtable] Key-value pairs from .env file

    .EXAMPLE
        $vars = Get-TemplateVariables
        # Returns: @{ PROJECT_NAME = "MyProject"; VERSION = "0.1.0" }
    #>
    param(
        [string]$EnvPath = '.env'
    )

    $variables = @{}

    if (-not (Test-Path $EnvPath)) {
        Write-Verbose "Env file not found: $EnvPath"
        return $variables
    }

    $content = Get-Content $EnvPath -Raw -Encoding utf8

    # Parse key=value pairs, skip comments and empty lines
    $content -split "`n" | ForEach-Object {
        $line = $_.Trim()

        # Skip comments and empty lines
        if ($line.StartsWith('#') -or [string]::IsNullOrWhiteSpace($line)) {
            return
        }

        # Parse key=value
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $variables[$key] = $value
        }
    }

    return $variables
}

function Get-ConfigBoxVariables {
    <#
    .SYNOPSIS
        Load variables from config.psd1 PowerShell config file

    .DESCRIPTION
        Reads config.psd1 and extracts key-value pairs from the hashtable.
        Supports nested keys (converts to uppercase with _ prefix).

    .PARAMETER ConfigPath
        Path to config.psd1 file. Defaults to box.psd1 in current directory.

    .OUTPUTS
        [hashtable] Configuration variables from box.psd1

    .EXAMPLE
        $config = Get-ConfigBoxVariables
        # Returns: @{ PROJECT_NAME = "MyProject"; VERSION = "0.1.0" }
    #>
    param(
        [string]$ConfigPath = 'box.psd1'
    )

    $variables = @{}

    if (-not (Test-Path $ConfigPath)) {
        Write-Verbose "Config file not found: $ConfigPath"
        return $variables
    }

    try {
        $data = Invoke-Expression (Get-Content $ConfigPath -Raw -Encoding utf8)

        if ($data -is [hashtable]) {
            foreach ($key in $data.Keys) {
                $variables[$key] = $data[$key]
            }
        }
    }
    catch {
        Write-Warning "Failed to parse config.psd1: $_"
    }

    return $variables
}

function Merge-TemplateVariables {
    <#
    .SYNOPSIS
        Merge .env and config.psd1 variables into single hashtable

    .DESCRIPTION
        Combines environment and config variables. Config variables take
        precedence over .env in case of conflicts.

    .PARAMETER EnvPath
        Path to .env file

    .PARAMETER ConfigPath
        Path to config.psd1 file

    .OUTPUTS
        [hashtable] Merged variables

    .EXAMPLE
        $vars = Merge-TemplateVariables
        # Returns merged hashtable with both .env and config.psd1 values
    #>
    param(
        [string]$EnvPath = '.env',
        [string]$ConfigPath = 'box.config.psd1'
    )

    $merged = @{}

    # Load .env first
    $envVars = Get-TemplateVariables -EnvPath $EnvPath
    foreach ($key in $envVars.Keys) {
        $merged[$key] = $envVars[$key]
    }

    # Load config.psd1 and override conflicts
    $configVars = Get-ConfigBoxVariables -ConfigPath $ConfigPath
    foreach ($key in $configVars.Keys) {
        $merged[$key] = $configVars[$key]
    }

    # Validate case sensitivity
    Test-TokenCaseSensitivity -Variables $merged

    return $merged
}

# ============================================================================
# TEMPLATE PROCESSING FUNCTIONS
# ============================================================================

function Process-Template {
    <#
    .SYNOPSIS
        Replace {{TOKEN}} placeholders in template with variable values

    .DESCRIPTION
        Scans template content for {{TOKEN}} patterns and replaces with values
        from variables hashtable. Unknown tokens are left as-is with warning.

    .PARAMETER TemplateContent
        Template file content as string

    .PARAMETER Variables
        Hashtable with variable values for replacement

    .PARAMETER TemplateName
        Template name for logging (optional)

    .OUTPUTS
        [string] Template content with tokens replaced

    .EXAMPLE
        $template = "PROJECT: {{PROJECT_NAME}}"
        $vars = @{ PROJECT_NAME = "MyApp" }
        $result = Process-Template -TemplateContent $template -Variables $vars
        # Returns: "PROJECT: MyApp"
    #>
    param(
        [string]$TemplateContent,
        [hashtable]$Variables,
        [string]$TemplateName = "template"
    )

    $result = $TemplateContent
    $tokensReplaced = 0
    $tokensUnknown = @()

    # Detect circular references
    Test-CircularReferences -Variables $Variables -TemplateName $TemplateName

    # Find all {{TOKEN}} patterns
    $pattern = '\{\{([A-Za-z_][A-Za-z0-9_]*)\}\}'
    $matches = [regex]::Matches($result, $pattern)

    foreach ($match in $matches) {
        $token = $match.Groups[1].Value
        $placeholder = $match.Groups[0].Value

        if ($Variables.ContainsKey($token)) {
            $value = $Variables[$token]
            # Escape $ in replacement value (PowerShell -replace treats $ as special)
            $safeValue = $value -replace '\$', '$$'
            $result = $result -replace [regex]::Escape($placeholder), $safeValue
            $tokensReplaced++
        }
        else {
            $tokensUnknown += $token
        }
    }

    # Report unknown tokens
    if ($tokensUnknown.Count -gt 0) {
        $unknownList = $tokensUnknown | Select-Object -Unique | Join-String -Separator ', '
        Write-Warning "Unknown tokens in $TemplateName : $unknownList"
    }

    Write-Verbose "Replaced $tokensReplaced tokens in $TemplateName"

    return $result
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

function Test-TokenCaseSensitivity {
    <#
    .SYNOPSIS
        Detect tokens with different cases (e.g., PROJECT_NAME vs project_name)

    .DESCRIPTION
        Checks if the same token exists in multiple case variations and warns the user.

    .PARAMETER Variables
        Hashtable with variable values

    .EXAMPLE
        Test-TokenCaseSensitivity -Variables @{ PROJECT_NAME = "App"; project_name = "app" }
        # Warns about case sensitivity issue
    #>
    param(
        [hashtable]$Variables
    )

    $lowercaseKeys = @{}
    $duplicates = @()

    foreach ($key in $Variables.Keys) {
        $lower = $key.ToLower()
        if ($lowercaseKeys.ContainsKey($lower)) {
            $duplicates += "$($lowercaseKeys[$lower]) vs $key"
        }
        else {
            $lowercaseKeys[$lower] = $key
        }
    }

    if ($duplicates.Count -gt 0) {
        $dupeList = $duplicates -join ', '
        Write-Warning "Case sensitivity issue detected in tokens: $dupeList"
    }
}

function Test-CircularReferences {
    <#
    .SYNOPSIS
        Detect circular token references in variables

    .DESCRIPTION
        Checks if variable values contain references to other variables that could
        create circular dependencies (e.g., VAR1={{VAR2}}, VAR2={{VAR1}}).

    .PARAMETER Variables
        Hashtable with variable values

    .PARAMETER TemplateName
        Template name for logging

    .EXAMPLE
        Test-CircularReferences -Variables @{ VAR1 = "{{VAR2}}"; VAR2 = "{{VAR1}}" }
        # Warns about circular reference
    #>
    param(
        [hashtable]$Variables,
        [string]$TemplateName = "template"
    )

    $pattern = '\{\{([A-Za-z_][A-Za-z0-9_]*)\}\}'
    $circularRefs = @()

    foreach ($key in $Variables.Keys) {
        $value = $Variables[$key]
        if ($value -match $pattern) {
            $referencedToken = $matches[1]
            # Check if referenced token also references back
            if ($Variables.ContainsKey($referencedToken)) {
                $referencedValue = $Variables[$referencedToken]
                if ($referencedValue -match "\{\{$key\}\}") {
                    $circularRefs += "$key <-> $referencedToken"
                }
            }
        }
    }

    if ($circularRefs.Count -gt 0) {
        $circularList = $circularRefs | Select-Object -Unique | Join-String -Separator ', '
        Write-Warning "Circular reference detected in $TemplateName : $circularList"
    }
}

function Test-FileEncoding {
    <#
    .SYNOPSIS
        Validate that file is UTF-8 encoded

    .DESCRIPTION
        Checks file encoding to ensure it's UTF-8 compatible.

    .PARAMETER FilePath
        Path to file to validate

    .OUTPUTS
        [bool] True if UTF-8, False otherwise

    .EXAMPLE
        $isUtf8 = Test-FileEncoding -FilePath 'Makefile.template'
    #>
    param(
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return $false
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)

        # Check for UTF-8 BOM
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            return $true
        }

        # Try to decode as UTF-8
        $encoding = [System.Text.UTF8Encoding]::new($false, $true)
        try {
            $null = $encoding.GetString($bytes)
            return $true
        }
        catch {
            return $false
        }
    }
    catch {
        Write-Warning "Failed to validate encoding for $FilePath : $_"
        return $false
    }
}

function Test-TemplateFileSize {
    <#
    .SYNOPSIS
        Validate template file size is within acceptable limits

    .DESCRIPTION
        Checks if file is larger than 10MB and rejects it to prevent performance issues.

    .PARAMETER FilePath
        Path to template file

    .OUTPUTS
        [bool] True if acceptable size, False if too large

    .EXAMPLE
        $isValid = Test-TemplateFileSize -FilePath 'large.template'
    #>
    param(
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return $false
    }

    $maxSizeBytes = 10MB
    $fileSize = (Get-Item $FilePath).Length

    if ($fileSize -gt $maxSizeBytes) {
        $sizeMB = [math]::Round($fileSize / 1MB, 2)
        Write-Error "Template file too large: $FilePath ($sizeMB MB). Maximum size is 10 MB."
        return $false
    }

    return $true
}

function Test-FileWritePermission {
    <#
    .SYNOPSIS
        Test if current user has write permission to path

    .DESCRIPTION
        Checks write access to a directory or file without actually writing.

    .PARAMETER Path
        Path to test (file or directory)

    .OUTPUTS
        [bool] True if writable, False otherwise

    .EXAMPLE
        $canWrite = Test-FileWritePermission -Path 'C:\Projects'
    #>
    param(
        [string]$Path
    )

    try {
        $testPath = $Path
        if (Test-Path $testPath -PathType Container) {
            $testFile = Join-Path $testPath ".write_test_$(Get-Random)"
        }
        else {
            $testFile = "$Path.write_test"
        }

        # Try to create a test file
        $null = New-Item -Path $testFile -ItemType File -Force -ErrorAction Stop
        Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        return $false
    }
}

# ============================================================================
# FILE MANAGEMENT FUNCTIONS
# ============================================================================

function Backup-File {
    <#
    .SYNOPSIS
        Create timestamped backup of file before modification

    .DESCRIPTION
        Copies file to .bak.TIMESTAMP version to preserve original.
        Uses format: filename.bak.yyyyMMdd-HHmmss

    .PARAMETER FilePath
        Path to file to backup

    .PARAMETER Force
        Overwrite existing backup (optional)

    .OUTPUTS
        [string] Path to backup file created

    .EXAMPLE
        $backupPath = Backup-File -FilePath 'Makefile'
        # Creates: Makefile.bak.20251224-143045
    #>
    param(
        [string]$FilePath,
        [switch]$Force
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found for backup: $FilePath"
        return $null
    }

    # Test write permission before attempting backup
    $directory = Split-Path $FilePath -Parent
    if (-not (Test-FileWritePermission -Path $directory)) {
        Write-Error "Insufficient permissions to create backup in: $directory"
        return $null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "$FilePath.bak.$timestamp"

    try {
        Copy-Item -Path $FilePath -Destination $backupPath -Force:$Force -ErrorAction Stop
        Write-Verbose "Backed up to: $backupPath"
        return $backupPath
    }
    catch {
        Write-Error "Failed to backup $FilePath : $_"
        return $null
    }
}

function New-GenerationHeader {
    <#
    .SYNOPSIS
        Create file header comment indicating auto-generation

    .DESCRIPTION
        Returns a comment block that warns users not to edit the file directly.
        Includes generation timestamp for tracking.

    .PARAMETER FileType
        Type of file (for comment syntax): 'makefile', 'powershell', 'markdown', etc.

    .OUTPUTS
        [string] Comment header for file

    .EXAMPLE
        $header = New-GenerationHeader -FileType 'makefile'
        # Returns: "# Generated by DevBox - DO NOT EDIT\n# Generated: 2025-12-24 14:30:45"
    #>
    param(
        [ValidateSet('makefile', 'powershell', 'markdown', 'generic')]
        [string]$FileType = 'generic'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $prefix = switch ($FileType) {
        'makefile' { '#' }
        'powershell' { '#' }
        'markdown' { '<!--' }
        default { '#' }
    }

    $suffix = if ($FileType -eq 'markdown') { '-->' } else { '' }

    $header = @"
$prefix Generated by DevBox - DO NOT EDIT
$prefix Generated: $timestamp
$suffix
"@

    return $header.TrimEnd()
}

function Get-AvailableTemplates {
    <#
    .SYNOPSIS
        List all available template files in .box/tpl/

    .DESCRIPTION
        Discovers all .template files in .box/tpl/ directory.

    .PARAMETER TemplateDir
        Path to templates directory. Defaults to .box/tpl/

    .OUTPUTS
        [array] Array of template filenames (without .template extension)

    .EXAMPLE
        $templates = Get-AvailableTemplates
        # Returns: @( "Makefile", "README.md", "Makefile.amiga" )
    #>
    param(
        [string]$TemplateDir = '.box/tpl'
    )

    $templates = @()

    if (-not (Test-Path $TemplateDir)) {
        Write-Verbose "Templates directory not found: $TemplateDir"
        return $templates
    }

    Get-ChildItem -Path $TemplateDir -Filter '*.template*' -File | ForEach-Object {
        # Remove .template or .template.* extension
        $name = $_.Name -replace '\.template.*$', ''
        # Add back the extension if it's a secondary extension (like .md)
        if ($_.Name -match '\.template\.(\w+)$') {
            $name = $name + '.' + $Matches[1]
        }
        $templates += $name
    }

    return $templates
}

# ============================================================================
# BOX INIT - GENERATE FILES FROM TEMPLATES
# ============================================================================

function Invoke-BoxInit {
    <#
    .SYNOPSIS
        Generate project files from .box/tpl/ templates

    .DESCRIPTION
        Reads template files from .box/tpl/ and generates corresponding files
        in the project root. Replaces {{TOKEN}} placeholders with values from
        box.config.psd1 and .env.

        Only creates missing files - safe to re-run without overwriting existing files.

    .EXAMPLE
        Invoke-BoxInit
        Generates all missing files from templates
    #>

    Write-Host ""
    Write-Host "━" * 60 -ForegroundColor DarkCyan
    Write-Host "  Generating Files from Templates" -ForegroundColor Cyan
    Write-Host "━" * 60 -ForegroundColor DarkCyan

    # Check if we're in a project with .box/
    if (-not (Test-Path ".box")) {
        Write-Host "  ❌ Not in a DevBox project (no .box/ directory found)" -ForegroundColor Red
        Write-Host "  Run 'devbox init' to create a new project" -ForegroundColor Gray
        return
    }

    # Load configuration
    $configVars = Get-ConfigBoxVariables

    # Load environment variables
    $envVars = Get-TemplateVariables

    # Merge both (env overrides config)
    $allVars = $configVars.Clone()
    foreach ($key in $envVars.Keys) {
        $allVars[$key] = $envVars[$key]
    }

    # Find all template files
    $templatePath = ".box/tpl"
    if (-not (Test-Path $templatePath)) {
        Write-Host "  ❌ Template directory not found: $templatePath" -ForegroundColor Red
        return
    }

    $templates = Get-ChildItem -Path $templatePath -Filter "*.template*" -File
    if ($templates.Count -eq 0) {
        Write-Warning "No template files found in $templatePath"
        return
    }

    Write-Host ""
    $generated = 0
    $skipped = 0

    foreach ($template in $templates) {
        # Determine output filename
        $outputName = $template.Name -replace '\.template', ''
        $outputPath = Join-Path (Get-Location) $outputName

        # Skip if file already exists
        if (Test-Path $outputPath) {
            Write-Host "  ⏭️  Skipping $outputName (already exists)" -ForegroundColor Gray
            $skipped++
            continue
        }

        # Read template content
        $content = Get-Content $template.FullName -Raw -Encoding UTF8

        # Replace all {{TOKEN}} placeholders
        foreach ($key in $allVars.Keys) {
            $content = $content -replace "{{$key}}", $allVars[$key]
        }

        # Write output file
        try {
            Set-Content -Path $outputPath -Value $content -Encoding UTF8 -NoNewline
            Write-Host "  ✅ Generated $outputName" -ForegroundColor Green
            $generated++
        }
        catch {
            Write-Host "  ❌ Failed to create $outputName`: $_" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "━" * 60 -ForegroundColor DarkCyan
    Write-Host "  Summary: $generated generated, $skipped skipped" -ForegroundColor Cyan
    Write-Host "━" * 60 -ForegroundColor DarkCyan

    if ($generated -eq 0 -and $skipped -gt 0) {
        Write-Host ""
        Write-Host "  💡 All files already exist. Use 'box env update' to regenerate." -ForegroundColor Yellow
    }
}
