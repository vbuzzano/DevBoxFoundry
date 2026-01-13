# ============================================================================
# Box Uninstall Module
# ============================================================================
#
# Handles box uninstall command - removing installed packages

function Invoke-Box-Uninstall {
    <#
    .SYNOPSIS
    Uninstalls all packages from the project.

    .EXAMPLE
    box uninstall
    #>

    Write-Title "Uninstall Environment"

    # Check for custom uninstall script
    $uninstallScript = Join-Path $BoxDir "uninstall.ps1"
    if (Test-Path $uninstallScript) {
        & $uninstallScript
    } else {
        # Default uninstall: remove all package files
        $state = Load-State
        if ($state.packages) {
            foreach ($pkgName in $state.packages.Keys) {
                Write-Step "Removing $pkgName"
                Remove-Package -Name $pkgName
            }
        }

        # Remove vendor directory
        if (Test-Path $VendorDir) {
            Remove-Item $VendorDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Success "Removed vendor directory"
        }

        # Remove state file
        if (Test-Path $StateFile) {
            Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
            Write-Success "Removed state file"
        }

        Write-Success "Uninstall complete"
    }
}
