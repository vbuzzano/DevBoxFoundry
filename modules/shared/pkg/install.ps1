# ============================================================================
# Package Installation Module
# ============================================================================
#
# Main package installation logic with user interaction and state management.

function Process-Package {
    <#
    .SYNOPSIS
    Processes a package installation with user interaction.

    .DESCRIPTION
    Handles the complete package installation workflow:
    - Checks if package already installed (system/vendor/env)
    - Prompts user for installation decisions
    - Downloads and extracts package
    - Updates package state
    - Handles manual configuration if user refuses install

    .PARAMETER Item
    Hashtable with package definition (Name, Url, File, Archive, Extract, Mode, etc.)

    .EXAMPLE
    Process-Package -Item $packageDef
    #>
    param([hashtable]$Item)

    $name = $Item.Name
    $mode = if ($Item.Mode) { $Item.Mode } else { "auto" }
    $pkgState = Get-PackageState $name
    $isInstalled = $pkgState -and $pkgState.installed
    $isManual = $pkgState -and -not $pkgState.installed
    $existingEnvs = if ($pkgState -and $pkgState.envs) { $pkgState.envs } else { @{} }

    Write-Step "$name - $($Item.Description)"

    # Check if package already installed via system/vendor/env
    $detection = Test-PackageInstalled -Package $Item

    # Skip the "install anyway?" prompt for local installations (state/vendor source)
    # Go directly to the "Local installation found" prompt instead
    if ($detection.Installed -and $detection.Source -notin @("state", "vendor")) {
        # Prompt user to use existing installation (global/system only)
        $sourceLabel = if ($detection.Source -eq "env") { "global" } elseif ($detection.Source -eq "command") { "system" } else { $detection.Source }
        Write-Info "Found $sourceLabel installation: $($detection.Path)"
        $useExisting = Ask-Choice "Install locally in project anyway? [y/N]"

        if ($useExisting -ne "Y") {
            Write-Success "Using $sourceLabel $name"
            # Don't save any state - we're just using the existing installation
            # The detection will find it again next time
            return
        }
        # User chose to install anyway, continue below
    }

    # Already installed -> ask: Keep, Reinstall, Manual
    if ($isInstalled) {
        $choice = Ask-Choice "Local installation found. [K]eep / [R]einstall / [M]anual?"

        switch ($choice) {
            "K" {
                Write-Info "Keeping existing local installation"
                return
            }
            "R" {
                Write-Info "Removing previous installation..."
                Remove-Package $name
                # Continue to install below
            }
            "M" {
                $envs = Ask-ManualEnvs -ExtractRules $Item.Extract -ExistingEnvs $existingEnvs
                Set-PackageState -Name $name -Installed $false -Files @() -Dirs @() -Envs $envs
                Write-Success "Manual paths configured"
                return
            }
        }
    }
    # Manual config exists -> ask: Skip, Install, Reconfigure
    elseif ($isManual) {
        $choice = Ask-Choice "$name has manual config. [S]kip / [I]nstall / [R]econfigure?"

        switch ($choice) {
            "S" {
                Write-Info "Skipped"
                return
            }
            "I" {
                # Continue to install below
            }
            "R" {
                $envs = Ask-ManualEnvs -ExtractRules $Item.Extract -ExistingEnvs $existingEnvs
                Set-PackageState -Name $name -Installed $false -Files @() -Dirs @() -Envs $envs
                Write-Success "Manual paths reconfigured"
                return
            }
        }
    }
    # Not installed -> ask if mode=ask, otherwise auto-install
    else {
        if ($mode -eq "ask") {
            $choice = Ask-Choice "Install? [Y/n]"

            if ($choice -eq "N") {
                # User refused install, validate dependencies
                try {
                    $envs = Validate-PackageDependencies -Package $Item
                    Set-PackageState -Name $name -Installed $false -Files @() -Dirs @() -Envs $envs
                    Write-Success "Manual paths configured"
                } catch {
                    Write-Err "Dependency validation failed: $_"
                }
                return
            }
        }
        # mode=auto or user said Yes -> continue to install
    }

    # Detect SourceType
    $sourceType = if ($Item.SourceType) { $Item.SourceType } else { "http" }

    # Download and install
    $archive = Download-File -Url $Item.Url -FileName $Item.File -SourceType $sourceType

    if (-not $archive) {
        Write-Err "Download failed for $name"
        return
    }

    if ($Item.Archive -eq "file") {
        $result = Install-SingleFile -FilePath $archive -Name $name -ExtractRules $Item.Extract
    } else {
        $result = Extract-Package -Archive $archive -Name $name -ArchiveType $Item.Archive -ExtractRules $Item.Extract
    }

    Set-PackageState -Name $name -Installed $true -Files $result.Files -Dirs $result.Dirs -Envs $result.Envs
    Write-Success "Installed"
}
