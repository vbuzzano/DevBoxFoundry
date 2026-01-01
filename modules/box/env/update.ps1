# ============================================================================
# Box Env Module - Update subcommand
# ============================================================================

function Invoke-Box-Env-Update {
    <#
    .SYNOPSIS
    Updates .env file and VS Code settings from installed packages.

    .DESCRIPTION
    Regenerates .env file from all installed package configurations,
    updates VS Code terminal environment variables, and updates
    tagged files throughout the project.

    .EXAMPLE
    box env update
    #>

    Generate-AllEnvFiles
    Update-VSCodeEnv
    Update-TaggedFiles -Path $BaseDir -Recurse
    Write-Success ".env updated"
}

function Update-VSCodeEnv {
    <#
    .SYNOPSIS
    Updates .vscode/settings.json with environment variables from .env file.
    Only updates the terminal.integrated.env.windows section.
    #>
    $envFile = Join-Path $BaseDir ".env"
    $settingsFile = Join-Path $BaseDir ".vscode\settings.json"

    if (-not (Test-Path $settingsFile)) {
        Write-Verbose ".vscode/settings.json not found, skipping VS Code env update"
        return
    }

    if (-not (Test-Path $envFile)) {
        Write-Verbose ".env file not found, skipping VS Code env update"
        return
    }

    # Parse .env file
    $envVars = @{}
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            # Remove quotes if present
            $value = $value -replace '^"(.*)"$', '$1'
            $value = $value -replace "^'(.*)'$", '$1'
            $envVars[$key] = $value
        }
    }

    if ($envVars.Count -eq 0) {
        Write-Verbose "No variables found in .env"
        return
    }

    # Read settings.json
    try {
        $settingsContent = Get-Content $settingsFile -Raw -Encoding UTF8
        $settings = $settingsContent | ConvertFrom-Json -AsHashtable
    }
    catch {
        Write-Warn "Failed to parse .vscode/settings.json: $_"
        return
    }

    # Update terminal.integrated.env.windows
    if (-not $settings.ContainsKey('terminal.integrated.env.windows')) {
        $settings['terminal.integrated.env.windows'] = @{}
    }

    # Merge .env vars into existing settings (keep user-added variables)
    $existingEnv = $settings['terminal.integrated.env.windows']
    foreach ($key in $envVars.Keys) {
        $existingEnv[$key] = $envVars[$key]
    }
    $settings['terminal.integrated.env.windows'] = $existingEnv

    # Save back to file
    try {
        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
        Write-Verbose "Updated .vscode/settings.json with $($envVars.Count) environment variables"
    }
    catch {
        Write-Warn "Failed to save .vscode/settings.json: $_"
    }
}
