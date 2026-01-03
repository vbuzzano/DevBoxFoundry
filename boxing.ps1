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

# Detect execution mode
function Initialize-Mode {
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

# Discover and load shared modules
function Import-SharedModules {
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
        [string[]]$Arguments
    )

    try {
        # Auto-installation if no arguments AND not already installed
        if (-not $Arguments -or $Arguments.Count -eq 0) {
            # Check if Boxing is already installed
            $BoxingInstalled = Test-Path "$env:USERPROFILE\Documents\PowerShell\Boxing\boxer.ps1"
            
            if (-not $BoxingInstalled) {
                # First-time installation
                return Install-BoxingSystem
            }
            # If already installed, continue to show help
        }

        # Step 1: Detect mode
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
            $cmdArgs = $Arguments[1..($Arguments.Count - 1)]

            return Invoke-Command -CommandName $command -Arguments $cmdArgs
        }
        else {
            Show-Help
            return 0
        }
    }
    catch {
        Write-Error "Boxing initialization failed: $_"
        return 1
    }
}

# Export main entry point
Export-ModuleMember -Function Initialize-Boxing
