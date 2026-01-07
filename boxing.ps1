# Boxing - Common bootstrapper for boxer and box
#
# This script serves as the shared foundation for both boxer.ps1 (global manager)
# and box.ps1 (project manager). It handles:
# - Mode detection (boxer vs box)
# - Core library loading
# - Module discovery and loading
# - Command dispatching

# Strict mode for better error detection
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Global variables
$script:BoxingRoot = $PSScriptRoot
$script:Mode = $null
$script:LoadedModules = @{}
$script:Commands = @{}

# Embedded flag - set to $true by build process for compiled versions
if (-not (Get-Variable -Name IsEmbedded -Scope Script -ErrorAction SilentlyContinue)) {
    $script:IsEmbedded = $false
}

# Detect execution mode
function Initialize-Mode {
    # When executed via irm|iex, $MyInvocation.PSCommandPath is empty
    # In this case, default to 'boxer' mode for installation
    if (-not $MyInvocation.PSCommandPath) {
        $script:Mode = 'boxer'
        return $script:Mode
    }

    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.PSCommandPath)

    if ($scriptName -eq 'boxer') {
        $script:Mode = 'boxer'
    }
    elseif ($scriptName -eq 'box') {
        $script:Mode = 'box'
    }
    else {
        throw "Unknown execution mode. Script must be named 'boxer.ps1' or 'box.ps1'"
    }

    return $script:Mode
}

# Load core libraries
function Import-CoreLibraries {
    # Skip if embedded version - libraries already loaded
    if ($script:IsEmbedded) {
        Write-Verbose "Embedded mode: core libraries already loaded"
        return
    }

    $corePath = Join-Path $script:BoxingRoot 'core'

    if (-not (Test-Path $corePath)) {
        throw "Core directory not found: $corePath"
    }

    $coreFiles = Get-ChildItem -Path $corePath -Filter '*.ps1' | Sort-Object Name

    foreach ($file in $coreFiles) {
        try {
            . $file.FullName
            Write-Verbose "Loaded core: $($file.Name)"
        }
        catch {
            throw "Failed to load core library $($file.Name): $_"
        }
    }
}

# Discover and load mode-specific modules
function Import-ModeModules {
    param([string]$Mode)

    # Skip if embedded version - modules already loaded
    if ($script:IsEmbedded) {
        Write-Verbose "Embedded mode: $Mode modules already loaded"
        # Still need to register commands for embedded version
        Register-EmbeddedCommands -Mode $Mode
        return
    }

    $modulesPath = Join-Path $script:BoxingRoot "modules\$Mode"

    if (-not (Test-Path $modulesPath)) {
        Write-Verbose "No modules found for mode: $Mode"
        return
    }

    $moduleFiles = Get-ChildItem -Path $modulesPath -Filter '*.ps1' | Sort-Object Name

    foreach ($file in $moduleFiles) {
        try {
            . $file.FullName

            $commandName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $script:Commands[$commandName] = $file.FullName
            $script:LoadedModules[$file.Name] = $file.FullName

            Write-Verbose "Loaded module: $Mode/$($file.Name)"
        }
        catch {
            Write-Warning "Failed to load module $($file.Name): $_"
        }
    }
}

# Register embedded commands (when modules are already loaded)
function Register-EmbeddedCommands {
    param([string]$Mode)

    # For embedded versions, register known commands
    if ($Mode -eq 'boxer') {
        $script:Commands['init'] = 'Invoke-Boxer-Init'
        $script:Commands['install'] = 'Install-Box'
        $script:Commands['list'] = 'Invoke-Boxer-List'
        $script:Commands['version'] = 'Invoke-Boxer-Version'
    }
    elseif ($Mode -eq 'box') {
        $script:Commands['install'] = 'Invoke-Box-Install'
        $script:Commands['env'] = 'Invoke-Box-Env'
        $script:Commands['clean'] = 'Invoke-Box-Clean'
        $script:Commands['status'] = 'Invoke-Box-Status'
        $script:Commands['uninstall'] = 'Invoke-Box-Uninstall'
        $script:Commands['version'] = 'Invoke-Box-Version'
    }
}

# Discover and load shared modules
function Import-SharedModules {
    # Skip if embedded version - shared modules already loaded
    if ($script:IsEmbedded) {
        Write-Verbose "Embedded mode: shared modules already loaded"
        return
    }

    $sharedPath = Join-Path $script:BoxingRoot 'modules\shared'

    if (-not (Test-Path $sharedPath)) {
        Write-Verbose "No shared modules found"
        return
    }

    # Load complex modules with metadata
    $metadataFiles = Get-ChildItem -Path $sharedPath -Filter 'metadata.psd1' -Recurse

    foreach ($metaFile in $metadataFiles) {
        try {
            $metadata = Import-PowerShellDataFile -Path $metaFile.FullName
            $moduleName = $metadata.ModuleName
            $moduleDir = $metaFile.Directory.FullName

            # Load all .ps1 files in the module directory
            $moduleFiles = Get-ChildItem -Path $moduleDir -Filter '*.ps1'

            foreach ($file in $moduleFiles) {
                . $file.FullName
                Write-Verbose "Loaded shared module: $moduleName/$($file.Name)"
            }

            # Register module commands
            if ($metadata.Commands) {
                foreach ($cmd in $metadata.Commands) {
                    $script:Commands[$cmd] = $moduleName
                }
            }

            $script:LoadedModules[$moduleName] = $moduleDir
        }
        catch {
            Write-Warning "Failed to load shared module $($metaFile.Directory.Name): $_"
        }
    }
}

# Dispatch command to appropriate handler
function Invoke-Command {
    param(
        [string]$CommandName,
        [string[]]$Arguments
    )

    if (-not $script:Commands.ContainsKey($CommandName)) {
        Write-Error "Unknown command: $CommandName"
        Show-Help
        return 1
    }

    try {
        # Build function name from command
        $functionName = "Invoke-$($script:Mode)-$CommandName"

        if (Get-Command $functionName -ErrorAction SilentlyContinue) {
            & $functionName @Arguments
            return $LASTEXITCODE
        }
        else {
            Write-Error "Command handler not found: $functionName"
            return 1
        }
    }
    catch {
        Write-Error "Command execution failed: $_"
        return 1
    }
}

# Main bootstrapping function
function Initialize-Boxing {
    param(
        [string[]]$Arguments = @()
    )

    try {
        # Auto-installation/update if executed via irm|iex (no $PSScriptRoot)
        if (-not $PSScriptRoot -and $Arguments.Count -eq 0) {
            $BoxerInstalled = "$env:USERPROFILE\Documents\PowerShell\Boxing\boxer.ps1"

            # 1. Check if already installed
            if (Test-Path $BoxerInstalled) {
                # 2. Compare versions
                $InstalledContent = Get-Content $BoxerInstalled -Raw
                $InstalledVersion = if ($InstalledContent -match 'Version:\s*(\S+)') { $Matches[1] } else { $null }

                # Get current version via core API (works in all modes)
                $CurrentVersion = Get-BoxerVersion

                # 3. Decision: upgrade only if new version > installed version
                try {
                    if ($InstalledVersion -and $CurrentVersion -and ([version]$CurrentVersion -gt [version]$InstalledVersion)) {
                        Write-Host ""
                        Write-Host "🔄 Boxer update: $InstalledVersion → $CurrentVersion" -ForegroundColor Cyan
                        Install-BoxingSystem | Out-Null
                        return
                    } elseif ($InstalledVersion -and $CurrentVersion) {
                        # Already up-to-date or newer installed
                        Write-Host "✓ Boxer already up-to-date (v$InstalledVersion)" -ForegroundColor Green
                        # Check if box needs update (Install-BoxingSystem handles this)
                        Install-BoxingSystem | Out-Null
                        return
                    }
                } catch {
                    # Version parsing failed, skip update
                }
            } else {
                # First-time installation
                Install-BoxingSystem | Out-Null
                return
            }
        }        # Step 1: Detect mode
        $mode = Initialize-Mode
        Write-Verbose "Mode: $mode"

        # Step 2: Load core libraries
        Import-CoreLibraries
        Write-Verbose "Core libraries loaded"

        # Step 3: Load mode-specific modules
        Import-ModeModules -Mode $mode
        Write-Verbose "Mode modules loaded: $($script:Commands.Count) commands"

        # Step 4: Load shared modules
        Import-SharedModules
        Write-Verbose "Shared modules loaded"

        # Step 5: Dispatch command
        if ($Arguments.Count -gt 0) {
            $command = $Arguments[0]
            $cmdArgs = if ($Arguments.Count -gt 1) {
                $Arguments[1..($Arguments.Count - 1)]
            } else {
                @()
            }

            Invoke-Command -CommandName $command -Arguments $cmdArgs | Out-Null
        }
        else {
            Show-Help
        }
    }
    catch {
        Write-Error "Boxing initialization failed: $_"
        return 1
    }
}

# Note: Export-ModuleMember removed - not needed in standalone scripts
