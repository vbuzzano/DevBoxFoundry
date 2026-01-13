# ============================================================================
# Box Load Module
# ============================================================================
#
# Handles box load command - complete environment setup in one command

function Invoke-Box-Load {
    <#
    .SYNOPSIS
    Loads the complete Boxing environment in one command.

    .DESCRIPTION
    This command does everything needed to start working:
    1. Updates .env file from packages
    2. Updates VS Code settings
    3. Loads .env variables into current PowerShell session
    4. Adds .box/ and scripts/ to PATH

    .EXAMPLE
    box load
    #>
    param()

    Write-Host ""
    Write-Host "Loading Boxing environment..." -ForegroundColor Cyan
    Write-Host ""

    # 1. Generate .env file
    Write-Step "Updating .env file"
    Generate-AllEnvFiles
    Write-Success ".env updated"

    # 2. Update VS Code settings
    Write-Step "Updating VS Code settings"
    Update-VSCodeEnv
    Write-Success "VS Code env updated"

    # 3. Load .env into current session
    Write-Step "Loading environment into session"
    $envFile = Join-Path $BaseDir ".env"

    if (-not (Test-Path $envFile)) {
        Write-Err ".env file not found after update"
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
    Write-Success "Loaded $loadedCount variables into session"

    # 4. Add .box and scripts to PATH
    Write-Step "Updating PATH"
    $boxPath = Join-Path $BaseDir ".box"
    $scriptsPath = Join-Path $BaseDir "scripts"
    $env:PATH = "$boxPath;$scriptsPath;$env:PATH"
    Write-Success "Added .box/ and scripts/ to PATH"

    Write-Host ""
    Write-Host "✓ Boxing environment ready!" -ForegroundColor Green
    Write-Host ""
}
