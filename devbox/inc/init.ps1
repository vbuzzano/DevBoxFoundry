# ============================================================================
# AmigaDevBox - Initialization Module
# ============================================================================
# This file handles all box initialization: paths, configs, and functions.
# Dot-source this from box.ps1 to keep the main script clean.
# ============================================================================

# ============================================================================
# Constants (local to init, no $script: needed)
# ============================================================================

$CONFIG_FILENAME = 'config.psd1'
$USER_CONFIG_FILENAME = 'box.config.psd1'
$STATE_FILENAME = '.box/state.json'
$FUNCTIONS_LOADER = 'inc\functions.ps1'

# ============================================================================
# Derived Paths (BaseDir and BoxDir are set by caller)
# ============================================================================

$script:StateFile = Join-Path $BaseDir $STATE_FILENAME
$script:EnvFile = Join-Path $BaseDir ".env"

# ============================================================================
# Load Functions (before config loading - needed for Merge-Config)
# ============================================================================

$script:FunctionsLoader = Join-Path $BoxDir $FUNCTIONS_LOADER
if (-not (Test-Path $FunctionsLoader)) {
    Write-Host "Functions loader not found: $FunctionsLoader" -ForegroundColor Red
    exit 1
}
. $FunctionsLoader

# ============================================================================
# Configuration Loading
# ============================================================================

# Load system config
$script:SysConfigFile = Join-Path $BoxDir $CONFIG_FILENAME
if (-not (Test-Path $SysConfigFile)) {
    Write-Host "$CONFIG_FILENAME not found in .box/" -ForegroundColor Red
    exit 1
}
$script:SysConfig = Import-PowerShellDataFile $SysConfigFile

# User config
$script:UserConfigFile = Join-Path $BaseDir $USER_CONFIG_FILENAME
$script:UserConfigTemplate = Join-Path $BaseDir $SysConfig.UserConfigTemplate

# Project config (created by devbox init with PROJECT_NAME, DESCRIPTION)
$script:ProjectConfigFile = Join-Path $BoxDir 'project.psd1'

# Handle missing user config based on command
$script:SkipExecution = $false
$script:StateExists = Test-Path (Join-Path $BaseDir $STATE_FILENAME)

# Commands that require state (not install, not help)
if ($BoxCommand -in @("uninstall", "env", "pkg")) {
    if (-not $StateExists) {
        Write-Host ""
        Write-Host "No configuration found." -ForegroundColor Red
        Write-Host "Run 'box' or 'box install' first." -ForegroundColor Gray
        Write-Host ""
        $script:SkipExecution = $true
    }
}

# Load config if not skipping
if (-not $SkipExecution) {
    # Load project config if exists
    $script:ProjectConfig = @{}
    if (Test-Path $ProjectConfigFile) {
        $script:ProjectConfig = Import-PowerShellDataFile $ProjectConfigFile
    }

    if (Test-Path $UserConfigFile) {
        $script:UserConfig = Import-PowerShellDataFile $UserConfigFile
        $script:Config = Merge-Config -SysConfig $SysConfig -UserConfig $UserConfig
        # Merge project config into $Config
        foreach ($key in $ProjectConfig.Keys) {
            $script:Config[$key] = $ProjectConfig[$key]
        }
    }
    elseif ($BoxCommand -eq "install" -or $BoxCommand -eq "") {
        # install: will run wizard later in Invoke-Install
        $script:UserConfig = @{}
        $script:Config = $SysConfig
        # Still merge project config
        foreach ($key in $ProjectConfig.Keys) {
            $script:Config[$key] = $ProjectConfig[$key]
        }
        $script:NeedsWizard = $true
    }
    else {
        # Other commands without config but with state - use minimal config
        $script:UserConfig = @{}
        $script:Config = $SysConfig
    }
}

# ============================================================================
# Derived Paths (from merged config)
# ============================================================================

# Cache path (with override support)
$script:CacheDir = if ($Config.CachePath) { 
    if ([System.IO.Path]::IsPathRooted($Config.CachePath)) { $Config.CachePath } 
    else { Join-Path $BaseDir $Config.CachePath }
} else { 
    Join-Path $BaseDir $Config.BoxPaths.Cache 
}
$script:DownloadsDir = $CacheDir
$script:TempDir = Join-Path $CacheDir "temp"
$script:BoxToolsDir = Join-Path $BaseDir $Config.BoxPaths.Tools

# 7-Zip paths
$script:SevenZipExe = Join-Path $BoxToolsDir "7z.exe"
$script:SevenZipDll = Join-Path $BoxToolsDir "7z.dll"

# All packages (merged - UserConfig.Packages first for priority)
$script:AllPackages = if ($Config.Packages) { $Config.Packages } else { @() }
