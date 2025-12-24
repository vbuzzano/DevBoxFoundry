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

    $content = Get-Content $EnvPath -Raw

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
        Path to config.psd1 file. Defaults to box.config.psd1 in current directory.

    .OUTPUTS
        [hashtable] Configuration variables from box.config.psd1

    .EXAMPLE
        $config = Get-ConfigBoxVariables
        # Returns: @{ PROJECT_NAME = "MyProject"; VERSION = "0.1.0" }
    #>
    param(
        [string]$ConfigPath = 'box.config.psd1'
    )

    $variables = @{}

    if (-not (Test-Path $ConfigPath)) {
        Write-Verbose "Config file not found: $ConfigPath"
        return $variables
    }

    try {
        $data = Invoke-Expression (Get-Content $ConfigPath -Raw)

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

    # Find all {{TOKEN}} patterns
    $pattern = '\{\{([A-Za-z_][A-Za-z0-9_]*)\}\}'
    $matches = [regex]::Matches($result, $pattern)

    foreach ($match in $matches) {
        $token = $match.Groups[1].Value
        $placeholder = $match.Groups[0].Value

        if ($Variables.ContainsKey($token)) {
            $value = $Variables[$token]
            $result = $result -replace [regex]::Escape($placeholder), $value
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
        List all available template files in .box/templates/

    .DESCRIPTION
        Discovers all .template files in .box/templates/ directory.

    .PARAMETER TemplateDir
        Path to templates directory. Defaults to .box/templates/

    .OUTPUTS
        [array] Array of template filenames (without .template extension)

    .EXAMPLE
        $templates = Get-AvailableTemplates
        # Returns: @( "Makefile", "README.md", "Makefile.amiga" )
    #>
    param(
        [string]$TemplateDir = '.box/templates'
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
