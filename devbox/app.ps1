<#
.SYNOPSIS
    ApolloDevBox Development Environment Setup

.DESCRIPTION
    Manages the development environment for AmigaOS cross-compilation.

.PARAMETER Command
    The command to execute: install, uninstall, env, pkg, help

.EXAMPLE
    .\box.ps1                    # Install (default)
    .\box.ps1 install            # Install all
    .\box.ps1 uninstall          # Uninstall environment
    .\box.ps1 env list           # List environment variables
    .\box.ps1 env reset          # Regenerate env files
    .\box.ps1 env add KEY=VALUE  # Add environment variable
    .\box.ps1 pkg list           # List packages
    .\box.ps1 pkg update         # Update packages
    .\box.ps1 help               # Show help

.NOTES
    Author: Vincent Buzzano (ReddoC)
    Date: December 2025
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("install", "uninstall", "env", "pkg", "template", "help", "")]
    [string]$Command = "install",

    [Parameter(Position = 1)]
    [string]$SubCommand = "",

    [Parameter(Position = 2, ValueFromRemainingArguments = $true)]
    [string[]]$Args,

    [switch]$Help
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Quick Help (before loading config)
# ============================================================================

function Show-QuickHelp {
    Write-Host ""
    Write-Host "Usage: setup.ps1 [command] [subcommand]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  install          Install all dependencies (default)" -ForegroundColor White
    Write-Host "  uninstall        Remove all generated files (back to factory state)" -ForegroundColor White
    Write-Host "  env              Manage environment variables" -ForegroundColor White
    Write-Host "  pkg              Manage packages" -ForegroundColor White
    Write-Host "  template         Manage template generation" -ForegroundColor White
    Write-Host "  help             Show this help" -ForegroundColor White
    Write-Host ""
    Write-Host "Env subcommands:" -ForegroundColor Yellow
    Write-Host "  env list         List all environment variables" -ForegroundColor White
    Write-Host "  env update       Regenerate .env file" -ForegroundColor White
    Write-Host ""
    Write-Host "Pkg subcommands:" -ForegroundColor Yellow
    Write-Host "  pkg list         List all packages with status" -ForegroundColor White
    Write-Host "  pkg update       Update/install packages interactively" -ForegroundColor White
    Write-Host ""
    Write-Host "Template subcommands:" -ForegroundColor Yellow
    Write-Host "  template update  Regenerate all templates" -ForegroundColor White
    Write-Host "  template apply <name>  Regenerate specific template" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  box env update           # Regenerate all templates from .env and config" -ForegroundColor Gray
    Write-Host "  box template apply Makefile  # Regenerate only Makefile" -ForegroundColor Gray
    Write-Host "  box template apply README.md # Regenerate only README.md" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Template system replaces {{TOKEN}} with values from .env and config files." -ForegroundColor Cyan
    Write-Host "Backups are created automatically before regeneration (.bak.timestamp)." -ForegroundColor Cyan
    Write-Host ""
}

if ($Help -or $Command -eq "help") {
    Show-QuickHelp
    exit 0
}

# ============================================================================
# Base Paths (defined here, used by init.ps1)
# ============================================================================

$_scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ((Split-Path $_scriptDir -Leaf) -eq 'scripts') {
    $script:BaseDir = Split-Path -Parent $_scriptDir
} else {
    $script:BaseDir = $_scriptDir
}
$script:BoxDir = Join-Path $BaseDir ".box"
$script:BoxCommand = $Command

# ============================================================================
# Initialize (loads configs, functions, and derived paths)
# ============================================================================

$_initPath = Join-Path $BoxDir "inc\\init.ps1"
if (-not (Test-Path $_initPath)) {
    Write-Err "init.ps1 not found: $_initPath"
    exit 1
}
. $_initPath

# Exit early if init signals to skip
if ($SkipExecution) {
    exit 0
}

# ============================================================================
# Main
# ============================================================================

switch ($Command) {
    "install" {
        Invoke-Install
    }
    "uninstall" {
        Invoke-Uninstall
    }
    "env" {
        if ([string]::IsNullOrEmpty($SubCommand)) {
            Show-EnvList
        } else {
            Invoke-Env -Sub $SubCommand -Params $Args
        }
    }
    "pkg" {
        if ([string]::IsNullOrEmpty($SubCommand)) {
            Show-PackageList
        } else {
            Invoke-Pkg -Sub $SubCommand
        }
    }
    "template" {
        if ($SubCommand -eq "apply") {
            if ($Args.Count -eq 0) {
                Write-Host "Error: template name required" -ForegroundColor Red
                Write-Host "Usage: box template apply <name>" -ForegroundColor Yellow
                exit 1
            }
            Invoke-TemplateApply -Template $Args[0]
        }
        else {
            Invoke-EnvUpdate
        }
    }
    default {
        Invoke-Install
    }
}
