# ============================================================================
# Box Env Module - Load subcommand
# ============================================================================

function Invoke-Box-Env-Load {
    <#
    .SYNOPSIS
    Loads .env file into current PowerShell session environment variables.

    .DESCRIPTION
    Reads .env file and sets all variables as environment variables in the
    current PowerShell session. Also adds .box/ and scripts/ to PATH.

    .EXAMPLE
    box env load
    #>

    $envFile = Join-Path $BaseDir ".env"

    if (-not (Test-Path $envFile)) {
        Write-Err ".env file not found. Run 'box env update' first."
        return
    }

    $loadedCount = 0
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item "env:$key" $value
            $loadedCount++
        }
    }

    # Add .box and scripts to PATH
    $boxPath = Join-Path $BaseDir ".box"
    $scriptsPath = Join-Path $BaseDir "scripts"
    $env:PATH = "$boxPath;$scriptsPath;$env:PATH"

    Write-Success "Loaded $loadedCount variables from .env into session"
    Write-Info "Added to PATH: .box/, scripts/"
}
