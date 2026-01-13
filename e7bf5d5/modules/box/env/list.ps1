# ============================================================================
# Box Env Module - List subcommand
# ============================================================================

function Invoke-Box-Env-List {
    <#
    .SYNOPSIS
    Displays all environment variables configured for the project.

    .EXAMPLE
    box env list
    box env
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
