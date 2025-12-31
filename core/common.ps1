# ============================================================================
# Common Functions - State Management
# ============================================================================
#
# Consolidated common utilities, after extracting UI functions to ui.ps1
# and config functions to config.ps1. This file now contains:
# - State management (Load/Save/Get/Set/Remove package state)

# ============================================================================
# State Management
# ============================================================================

function Load-State {
    <#
    .SYNOPSIS
    Loads the package state from the state file.

    .DESCRIPTION
    Returns a hashtable with package installation state.
    Creates an empty state if file doesn't exist.

    .EXAMPLE
    $state = Load-State
    #>
    if (Test-Path $StateFile) {
        return Get-Content $StateFile -Raw | ConvertFrom-Json -AsHashtable
    }
    return @{ packages = @{} }
}

function Save-State {
    <#
    .SYNOPSIS
    Saves the package state to the state file.

    .PARAMETER State
    The state hashtable to save

    .EXAMPLE
    Save-State -State $state
    #>
    param([hashtable]$State)
    $State | ConvertTo-Json -Depth 10 | Out-File $StateFile -Encoding UTF8
}

function Get-PackageState {
    <#
    .SYNOPSIS
    Gets the state for a specific package.

    .PARAMETER Name
    The package name

    .EXAMPLE
    $pkgState = Get-PackageState -Name "vbcc"
    #>
    param([string]$Name)
    $state = Load-State
    if ($state.packages.ContainsKey($Name)) {
        return $state.packages[$Name]
    }
    return $null
}

function Set-PackageState {
    <#
    .SYNOPSIS
    Sets/updates the state for a specific package.

    .PARAMETER Name
    The package name

    .PARAMETER Installed
    Whether the package is installed

    .PARAMETER Files
    List of installed files

    .PARAMETER Dirs
    List of installed directories

    .PARAMETER Envs
    Environment variables set by the package

    .EXAMPLE
    Set-PackageState -Name "vbcc" -Installed $true -Files @() -Dirs @() -Envs @{}
    #>
    param(
        [string]$Name,
        [bool]$Installed,
        [array]$Files,
        [array]$Dirs,
        [hashtable]$Envs
    )
    $state = Load-State
    $state.packages[$Name] = @{
        installed = $Installed
        files = $Files
        dirs = if ($Dirs) { $Dirs } else { @() }
        envs = $Envs
        date = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    Save-State $state
}

function Remove-PackageState {
    <#
    .SYNOPSIS
    Removes the state for a specific package.

    .PARAMETER Name
    The package name

    .EXAMPLE
    Remove-PackageState -Name "vbcc"
    #>
    param([string]$Name)
    $state = Load-State
    if ($state.packages.ContainsKey($Name)) {
        $state.packages.Remove($Name)
        Save-State $state
    }
}
