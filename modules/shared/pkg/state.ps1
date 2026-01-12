# ============================================================================
# Package State Display Module
# ============================================================================
#
# Functions for displaying package state information from .box/state.json.

function Show-PackageState {
    <#
    .SYNOPSIS
    Displays the current package state from .box/state.json.

    .DESCRIPTION
    Shows the raw package state for debugging purposes, including:
    - Installation status
    - Installed files and directories
    - Environment variable configurations
    - Installation timestamps

    .EXAMPLE
    Show-PackageState
    #>

    $statePath = Join-Path $ProjectRoot ".box\state.json"

    if (-not (Test-Path $statePath)) {
        Write-Host ""
        Write-Host "No package state file found (.box/state.json)" -ForegroundColor Yellow
        Write-Host "Run 'box install' to initialize package state" -ForegroundColor Gray
        Write-Host ""
        return
    }

    try {
        $state = Get-Content $statePath -Raw | ConvertFrom-Json

        Write-Host ""
        Write-Host "Package State (.box/state.json):" -ForegroundColor Cyan
        Write-Host ""

        if (-not $state.packages -or $state.packages.PSObject.Properties.Count -eq 0) {
            Write-Host "  No packages installed" -ForegroundColor Gray
            Write-Host ""
            return
        }

        foreach ($pkgName in $state.packages.PSObject.Properties.Name) {
            $pkg = $state.packages.$pkgName

            Write-Host "  $pkgName" -ForegroundColor White
            Write-Host "    Installed: $($pkg.installed)" -ForegroundColor $(if ($pkg.installed) { "Green" } else { "Yellow" })

            if ($pkg.files -and $pkg.files.Count -gt 0) {
                Write-Host "    Files: $($pkg.files.Count) file(s)" -ForegroundColor Gray
            }

            if ($pkg.dirs -and $pkg.dirs.Count -gt 0) {
                Write-Host "    Directories: $($pkg.dirs.Count) dir(s)" -ForegroundColor Gray
            }

            if ($pkg.envs -and $pkg.envs.PSObject.Properties.Count -gt 0) {
                Write-Host "    Environment Variables:" -ForegroundColor Gray
                foreach ($envName in $pkg.envs.PSObject.Properties.Name) {
                    $envValue = $pkg.envs.$envName
                    Write-Host "      $envName = $envValue" -ForegroundColor DarkGray
                }
            }

            Write-Host ""
        }
    }
    catch {
        Write-Error "Failed to read package state: $_"
    }
}
