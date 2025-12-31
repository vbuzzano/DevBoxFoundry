# ============================================================================
# Package Dependency Validation Module
# ============================================================================
#
# Functions for validating package dependencies and manual configuration.

function Validate-PackageDependencies {
    <#
    .SYNOPSIS
    Validates that required environment variables exist when package installation is refused.

    .DESCRIPTION
    When user chooses not to install a package, this function:
    1. Extracts required env vars from Extract rules
    2. Checks if env vars already exist
    3. Prompts for manual paths if missing
    4. Validates paths with Test-Path
    5. Saves to .env file

    .PARAMETER Package
    Hashtable with package definition including Extract rules

    .OUTPUTS
    Hashtable of environment variable names and paths
    #>
    param([hashtable]$Package)

    # Extract required env vars from Extract rules
    $requiredEnvs = @()
    if ($Package.Extract) {
        foreach ($rule in $Package.Extract) {
            if ($rule -match ':([A-Z_]+)$') {
                $requiredEnvs += $Matches[1]
            }
        }
    }

    if ($requiredEnvs.Count -eq 0) {
        return @{}
    }

    $envPaths = @{}

    foreach ($envVar in $requiredEnvs) {
        # Check if already set
        $existingValue = [System.Environment]::GetEnvironmentVariable($envVar)
        if ($existingValue) {
            $envPaths[$envVar] = $existingValue
            Write-Info "$envVar already set to: $existingValue"
            continue
        }

        # Prompt for manual path
        Write-Warn "$envVar is required for compilation/build"

        while ($true) {
            $manualPath = Read-Host "Enter path for $envVar (or 'skip' to abort)"

            if ($manualPath -eq 'skip' -or [string]::IsNullOrWhiteSpace($manualPath)) {
                Write-Err "Missing required dependency: $envVar"
                throw "Cannot proceed without $envVar"
            }

            # Validate path
            if (Test-Path $manualPath) {
                $envPaths[$envVar] = $manualPath

                # Save to .env
                $envFilePath = Join-Path $ProjectRoot ".env"
                Add-Content -Path $envFilePath -Value "$envVar=$manualPath"

                # Set in current session
                [System.Environment]::SetEnvironmentVariable($envVar, $manualPath)

                Write-Success "Set $envVar=$manualPath"
                break
            } else {
                Write-Warn "Path not found: $manualPath"
                Write-Info "Please provide a valid path or type 'skip' to abort"
            }
        }
    }

    return $envPaths
}
