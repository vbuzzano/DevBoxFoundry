# ============================================================================
# Package Uninstallation Module
# ============================================================================
#
# Functions for removing installed packages.

function Remove-Package {
    <#
    .SYNOPSIS
    Removes an installed package.

    .DESCRIPTION
    Deletes all files and directories installed by the package,
    then removes the package state.

    .PARAMETER Name
    The package name

    .EXAMPLE
    Remove-Package -Name "vbcc"
    #>
    param([string]$Name)

    $pkgState = Get-PackageState $Name
    if (-not $pkgState) {
        Write-Warn "Package $Name not found in state"
        return
    }

    if ($pkgState.installed -and $pkgState.files) {
        Write-Info "Removing $($pkgState.files.Count) files and $($pkgState.dirs.Count) directories..."

        foreach ($file in $pkgState.files) {
            if (Test-Path $file) {
                Remove-Item $file -Recurse -Force -ErrorAction SilentlyContinue
                Write-Info "Removed: $file"
            }
        }
    }

    Remove-PackageState $Name
    Write-Success "Package $Name removed"
}
