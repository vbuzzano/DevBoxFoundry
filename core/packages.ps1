# ============================================================================
# Package Management Shim
# ============================================================================
#
# This file is a shim that redirects to the modular pkg module.
# All package functions are now in modules/shared/pkg/*.ps1
#
# Module structure:
# - modules/shared/pkg/metadata.psd1     - Module definition
# - modules/shared/pkg/state.ps1         - State management (6 functions)
# - modules/shared/pkg/extraction.ps1    - Extraction logic (7 functions)
# - modules/shared/pkg/dependencies.ps1  - Dependency validation (2 functions)
# - modules/shared/pkg/install.ps1       - Installation (1 function)
# - modules/shared/pkg/uninstall.ps1     - Uninstallation (1 function)
# - modules/shared/pkg/list.ps1          - Package listing (1 function)
#
# This shim exists for backward compatibility during the transition.
# Once all callers are updated to use the pkg module directly,
# this file can be removed.

Write-Warn "core/packages.ps1 is deprecated. Use modules/shared/pkg/*.ps1 instead."

# Load pkg module functions for backward compatibility
$pkgModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\shared\pkg"

if (Test-Path $pkgModulePath) {
    # Load all pkg module files
    Get-ChildItem -Path $pkgModulePath -Filter *.ps1 -Recurse | ForEach-Object {
        . $_.FullName
    }
} else {
    Write-Error "Package module not found: $pkgModulePath"
}
