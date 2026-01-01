# ============================================================================
# Box Env Module - Replace subcommand
# ============================================================================

function Invoke-Box-Env-Replace {
    <#
    .SYNOPSIS
    Replaces tagged values in files with environment variables.

    .DESCRIPTION
    Processes files and replaces tagged values with current environment
    variable values. Supports in-place updates (preserves tags) or
    release mode (strips tags).

    Syntaxes supported:
    - ~value[VAR_NAME]~ : Universal tag
    - Box-specific syntaxes via hooks (e.g., #define for C)

    .PARAMETER Path
    Path pattern to files to process (e.g., *.md, src/, README.md)

    .PARAMETER OutputDir
    If specified, copies processed files to this directory with tags stripped.
    If not specified, updates files in-place preserving tags.

    .PARAMETER Force
    Required for in-place updates to prevent accidental overwrites.

    .EXAMPLE
    box env replace *.md -Force
    Updates all Markdown files in-place

    .EXAMPLE
    box env replace . -OutputDir dist/ -Force
    Copies all files to dist/ with tags stripped (release mode)
    #>
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$OutputDir = $null,

        [switch]$Force
    )

    # Load variables
    $variables = Get-TemplateVariables
    if ($variables.Count -eq 0) {
        Write-Warn "No variables found in .env"
        return
    }

    # Determine mode
    $releaseMode = $null -ne $OutputDir

    # Require -Force for in-place updates
    if (-not $releaseMode -and -not $Force) {
        Write-Err "In-place replacement requires -Force flag"
        Write-Info "Use: box env replace $Path -Force"
        return
    }

    # Create output directory if needed
    if ($releaseMode -and -not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # Process files
    Update-TaggedFiles -Path $Path -ReleaseMode:$releaseMode -Variables $variables

    if ($releaseMode) {
        Write-Success "Files processed to $OutputDir (tags stripped)"
    } else {
        Write-Success "Files updated in-place (tags preserved)"
    }
}
