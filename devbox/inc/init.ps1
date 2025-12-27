# ============================================================================
# AmigaDevBox - Initialization Module
# ============================================================================
# This file handles all box initialization: paths, configs, and functions.
# Compiled version includes embedded system config.
# ============================================================================

# ============================================================================
# Constants
# ============================================================================

$USER_CONFIG_FILENAME = 'box.config.psd1'
$STATE_FILENAME = '.box/state.json'

# ============================================================================
# Embedded System Configuration (replaces external config.psd1)
# ============================================================================

$script:SysConfig = @{
    Directories = @(
        "build/asm"
        "build/obj"
        "dist"
    )
    MakefileTemplate = ".box/template/Makefile.template"
    BoxPaths = @{
        Cache = ".box/cache"
        Tools = ".box/tools"
    }
    UserConfigTemplate = ".box/template/box.config.template"
    Paths = @{
        SrcDir = "src"
        IncludeDir = "include"
        BuildDir = "build"
        AsmDir = "build/asm"
        ObjDir = "build/obj"
        DistDir = "dist"
        VendorDir = "vendor"
        ACP = "./.box/tools/acp.exe"
        GDB = "./.box/tools/bgdbserver"
    }
    Packages = @()
}

# ============================================================================
# Derived Paths (BaseDir and BoxDir are set by caller)
# ============================================================================

$script:StateFile = Join-Path $BaseDir $STATE_FILENAME
$script:EnvFile = Join-Path $BaseDir ".env"

# ============================================================================
# Configuration Loading
# ============================================================================

# User config
$script:UserConfigFile = Join-Path $BaseDir $USER_CONFIG_FILENAME

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
    if (Test-Path $UserConfigFile) {
        $script:UserConfig = Import-PowerShellDataFile $UserConfigFile
        $script:Config = Merge-Config -SysConfig $SysConfig -UserConfig $UserConfig
    }
    elseif ($BoxCommand -eq "install" -or $BoxCommand -eq "") {
        # install: will run wizard later in Invoke-Install
        $script:UserConfig = @{}
        $script:Config = $SysConfig
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
