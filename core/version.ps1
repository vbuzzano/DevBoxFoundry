# ============================================================================
# Version Management Functions
# ============================================================================

function Get-BoxerVersion {
    <#
    .SYNOPSIS
    Gets the current boxer version from various sources.

    .DESCRIPTION
    Returns the boxer version, trying in order:
    1. Embedded $script:BoxerVersion (compiled mode)
    2. boxer.version file (development mode)
    3. Header comment from boxer.ps1 (fallback)

    .OUTPUTS
    Version string (e.g., "1.0.10") or $null if not found
    #>

    # 1. Try embedded version (compiled/runtime)
    if ($script:BoxerVersion) {
        return $script:BoxerVersion
    }

    # 2. Try reading from source file (development mode)
    $versionFile = Join-Path $script:BoxingRoot "boxer.version"
    if (Test-Path $versionFile) {
        $version = (Get-Content $versionFile -Raw).Trim()
        if ($version) {
            return $version
        }
    }

    # 3. Try reading from boxer.ps1 header (fallback)
    $boxerFile = Join-Path $script:BoxingRoot "dist\boxer.ps1"
    if (Test-Path $boxerFile) {
        $content = Get-Content $boxerFile -Raw
        if ($content -match 'Version:\s*(\S+)') {
            return $Matches[1]
        }
    }

    # Not found
    return $null
}
