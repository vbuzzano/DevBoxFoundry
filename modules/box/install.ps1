# ============================================================================
# Box Install Module
# ============================================================================
#
# Handles box install command - installing packages in a project

function Invoke-Box-Install {
    <#
    .SYNOPSIS
    Installs all configured packages for the project.

    .EXAMPLE
    box install
    #>

    Write-Title "$($Config.Project.Name) Setup"

    # Run config wizard if needed
    if ($NeedsWizard) {
        if (-not (Invoke-ConfigWizard)) {
            return
        }
    }

    # Create directories
    Create-Directories

    # Ensure 7-Zip is available
    Ensure-SevenZip

    # Install all packages
    foreach ($pkg in $AllPackages) {
        try {
            Process-Package $pkg
        } catch {
            Write-Err "Failed to process $($pkg.Name): $_"
            Write-Info "Continuing with remaining packages..."
        }
    }

    # Cleanup
    Cleanup-Temp

    # Generate Makefile if box-specific
    if (Get-Command Setup-Makefile -ErrorAction SilentlyContinue) {
        Setup-Makefile
    }

    # Generate env files
    Generate-AllEnvFiles

    Show-InstallComplete
}
