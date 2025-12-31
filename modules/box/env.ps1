# ============================================================================
# Box Env Module
# ============================================================================
#
# Handles box env command - environment variable management

function Invoke-Box-Env {
    <#
    .SYNOPSIS
    Manages environment variables for the project.

    .PARAMETER Sub
    Subcommand: list, update

    .EXAMPLE
    box env list
    box env update
    #>
    param(
        [string]$Sub = "list"
    )

    switch ($Sub) {
        "list" {
            Show-EnvList
        }
        "update" {
            Generate-AllEnvFiles
            Write-Success ".env updated"
        }
        default {
            Write-Err "Unknown env subcommand: $Sub"
            Write-Info "Use: list, update"
        }
    }
}

function Show-EnvList {
    <#
    .SYNOPSIS
    Displays all environment variables configured for the project.
    #>
    Write-Host ""
    Write-Host "Environment Variables:" -ForegroundColor Cyan
    Write-Host ""

    $state = Load-State
    if ($state.packages) {
        foreach ($pkgName in $state.packages.Keys) {
            $pkg = $state.packages[$pkgName]
            if ($pkg.envs) {
                Write-Host "  $pkgName" -ForegroundColor White
                foreach ($envName in $pkg.envs.Keys) {
                    $envValue = $pkg.envs[$envName]
                    Write-Host ("    {0,-20} = {1}" -f $envName, $envValue) -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Info "No packages installed yet"
    }

    Write-Host ""
}
