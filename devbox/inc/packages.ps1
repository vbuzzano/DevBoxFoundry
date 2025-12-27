# ============================================================================
# Package Management Functions
# ============================================================================

function Test-PackageInstalled {
    <#
    .SYNOPSIS
    Checks if a package is already installed via system, vendor, or environment variable.

    .DESCRIPTION
    Detection priority:
    1. DetectEnv - Environment variable exists (fastest)
    2. DetectFile - File found in system PATH
    3. DetectFile - File found in vendor/tools/
    4. DetectCommand - Command executes successfully
    5. Package state - Previously installed by box

    .PARAMETER Package
    Hashtable with package definition including DetectEnv, DetectFile, DetectCommand properties

    .OUTPUTS
    PSCustomObject with properties: Installed (bool), Source (string), Path (string)
    #>
    param([hashtable]$Package)

    # Priority 1: Environment variable
    if ($Package.DetectEnv) {
        $envValue = [System.Environment]::GetEnvironmentVariable($Package.DetectEnv)
        if ($envValue) {
            Write-Info "Found $($Package.Name) via `$env:$($Package.DetectEnv): $envValue"
            return @{
                Installed = $true
                Source = "env"
                Path = $envValue
            }
        }
    }

    # Priority 2: File in system PATH
    if ($Package.DetectFile) {
        $systemCmd = Get-Command $Package.DetectFile -ErrorAction SilentlyContinue
        if ($systemCmd) {
            Write-Info "Found system $($Package.Name): $($systemCmd.Source)"
            return @{
                Installed = $true
                Source = "system"
                Path = $systemCmd.Source
            }
        }

        # Priority 3: File in vendor/tools/
        $vendorPath = Join-Path $VendorDir "tools/$($Package.DetectFile)"
        if (Test-Path $vendorPath) {
            Write-Info "Found local $($Package.Name): $vendorPath"
            return @{
                Installed = $true
                Source = "vendor"
                Path = $vendorPath
            }
        }
    }

    # Priority 4: Execute command test
    if ($Package.DetectCommand) {
        try {
            $null = Invoke-Expression "$($Package.DetectCommand) 2>&1"
            if ($LASTEXITCODE -eq 0) {
                Write-Info "Verified $($Package.Name) via: $($Package.DetectCommand)"
                return @{
                    Installed = $true
                    Source = "command"
                    Path = $Package.DetectCommand
                }
            }
        } catch {
            # Command failed, continue
        }
    }

    # Priority 5: Package state (installed by box previously)
    $state = Get-PackageState -Name $Package.Name
    if ($state -and $state.installed) {
        return @{
            Installed = $true
            Source = "state"
            Path = "vendor/$($Package.Name)"
        }
    }

    return @{
        Installed = $false
        Source = $null
        Path = $null
    }
}

function Ensure-Tool {
    <#
    .SYNOPSIS
    Ensures a critical tool is available, auto-installing to vendor/tools/ if missing.

    .DESCRIPTION
    Used for essential tools like 7z.exe that are required for package extraction.
    Checks system PATH first, then vendor/tools/, then auto-installs if missing.

    .PARAMETER ToolName
    Name of the tool executable (e.g., "7z.exe")

    .PARAMETER PackageConfig
    Hashtable with package definition for auto-install (Name, Url, File, Archive, Extract)

    .OUTPUTS
    String path to the tool executable
    #>
    param(
        [string]$ToolName,
        [hashtable]$PackageConfig
    )

    # Check system PATH
    $systemTool = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($systemTool) {
        Write-Info "Using system $ToolName from: $($systemTool.Source)"
        return $systemTool.Source
    }

    # Check vendor/tools/
    $vendorPath = Join-Path $VendorDir "tools/$ToolName"
    if (Test-Path $vendorPath) {
        Write-Info "Using local $ToolName from: $vendorPath"
        return $vendorPath
    }

    # Auto-install
    Write-Info "Installing $ToolName to vendor/tools/..."

    $sourceType = if ($PackageConfig.SourceType) { $PackageConfig.SourceType } else { "http" }
    $archive = Download-File -Url $PackageConfig.Url -FileName $PackageConfig.File -SourceType $sourceType

    if (-not $archive) {
        Write-Err "Failed to download $ToolName"
        throw "Cannot proceed without $ToolName"
    }

    $result = Extract-Package -Archive $archive -Name $PackageConfig.Name -ArchiveType $PackageConfig.Archive -ExtractRules $PackageConfig.Extract

    if (Test-Path $vendorPath) {
        Write-Success "$ToolName installed successfully"
        return $vendorPath
    } else {
        throw "$ToolName installation failed"
    }
}

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

function Remove-Package {
    param([string]$Name)

    $pkgState = Get-PackageState $Name
    if (-not $pkgState) { return }

    if ($pkgState.installed -and $pkgState.files) {
        foreach ($file in $pkgState.files) {
            if (Test-Path $file) {
                Remove-Item $file -Recurse -Force -ErrorAction SilentlyContinue
                Write-Info "Removed: $file"
            }
        }
    }

    Remove-PackageState $Name
}

function Process-Package {
    param([hashtable]$Item)

    $name = $Item.Name
    $mode = if ($Item.Mode) { $Item.Mode } else { "auto" }
    $pkgState = Get-PackageState $name
    $isInstalled = $pkgState -and $pkgState.installed
    $isManual = $pkgState -and -not $pkgState.installed
    $existingEnvs = if ($pkgState -and $pkgState.envs) { $pkgState.envs } else { @{} }

    Write-Step "$name - $($Item.Description)"

    # T029: Check if package already installed via system/vendor/env (US3)
    $detection = Test-PackageInstalled -Package $Item

    # Skip the "install anyway?" prompt for local installations (state/vendor source)
    # Go directly to the "Local installation found" prompt instead
    if ($detection.Installed -and $detection.Source -notin @("state", "vendor")) {
        # T030: Prompt user to use existing installation (global/system only)
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
                # T031-T032: User refused install, validate dependencies
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

    # Detect SourceType (T016)
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

function Show-PackageList {
    Write-Host ""
    Write-Host "Packages:" -ForegroundColor Cyan
    Write-Host ""

    $state = Load-State

    # Table columns
    $colName = 20
    $colEnv = 18
    $colValue = 35
    $colStatus = 9

    Write-Host ("  {0,-$colName} {1,-$colEnv} {2,-$colValue} {3}" -f "NAME", "ENV VARS", "DESCRIPTION", "INSTALLED") -ForegroundColor DarkGray
    Write-Host ("  {0,-$colName} {1,-$colEnv} {2,-$colValue} {3}" -f ("-" * $colName), ("-" * $colEnv), ("-" * $colValue), ("-" * $colStatus)) -ForegroundColor DarkGray

    foreach ($item in $AllPackages) {
        $name = $item.Name
        $pkgState = if ($state.packages.ContainsKey($name)) { $state.packages[$name] } else { $null }

        # Get ENV vars (from state if installed, from rules if not)
        $envVars = @{}
        if ($pkgState -and $pkgState.envs) {
            $envVars = $pkgState.envs
        } elseif ($item.Extract) {
            foreach ($rule in $item.Extract) {
                $parsed = Parse-ExtractRule $rule
                if ($parsed -and $parsed.EnvVar) {
                    $envVars[$parsed.EnvVar] = $null
                }
            }
        }

        # Status indicator (last column)
        $isInstalled = $pkgState -and $pkgState.installed
        $isManual = $pkgState -and -not $pkgState.installed
        $hasEnvVars = $envVars.Count -gt 0
        $statusMark = if ($isInstalled) { [char]0x1F60A } elseif ($isManual) { [char]0x1F4E6 } else { "" }
        $statusColor = if ($isInstalled) { "Green" } elseif ($isManual) { "Yellow" } else { "DarkGray" }

        # First line: package name + first ENV or description
        $firstEnv = $envVars.Keys | Select-Object -First 1

        Write-Host ("  {0,-$colName}" -f $name) -ForegroundColor White -NoNewline

        if ($firstEnv) {
            $firstValue = if ($envVars[$firstEnv]) { $envVars[$firstEnv] } else { $item.Description }
            $valueColor = if ($envVars[$firstEnv]) { "Gray" } else { "DarkGray" }
            Write-Host (" {0,-$colEnv}" -f $firstEnv) -ForegroundColor Cyan -NoNewline
            Write-Host (" {0,-$colValue}" -f $firstValue) -ForegroundColor $valueColor -NoNewline
        } else {
            Write-Host (" {0,-$colEnv} {1,-$colValue}" -f "", $item.Description) -ForegroundColor DarkGray -NoNewline
        }
        Write-Host $statusMark -ForegroundColor $statusColor

        # Additional ENV vars (skip first)
        $remaining = $envVars.Keys | Select-Object -Skip 1
        foreach ($envName in $remaining) {
            $envValue = if ($envVars[$envName]) { $envVars[$envName] } else { $item.Description }
            $valueColor = if ($envVars[$envName]) { "Gray" } else { "DarkGray" }

            Write-Host ("  {0,-$colName}" -f "") -NoNewline
            Write-Host (" {0,-$colEnv}" -f $envName) -ForegroundColor Cyan -NoNewline
            Write-Host (" {0,-$colValue}" -f $envValue) -ForegroundColor $valueColor
        }
    }

    Write-Host ""
}
