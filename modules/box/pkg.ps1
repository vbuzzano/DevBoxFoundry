# ============================================================================
# Package Management Dispatcher
# ============================================================================
#
# Provides pkg subcommand dispatcher for direct package management CLI access.
# Routes commands: install, list, validate, uninstall, state

function Invoke-Box-Pkg {
    <#
    .SYNOPSIS
    Package management dispatcher for box pkg subcommands.

    .DESCRIPTION
    Routes pkg subcommands to appropriate handlers:
    - install: Install specific package by name
    - list: Display all installed packages
    - validate: Check package dependencies
    - uninstall: Remove specific package
    - state: Display package state from state.json
    - (no subcommand): Display help

    .PARAMETER Subcommand
    Package action to perform (install, list, validate, uninstall, state)

    .PARAMETER Args
    Arguments to pass to the subcommand handler

    .EXAMPLE
    Invoke-Box-Pkg 'list'
    Displays all installed packages

    .EXAMPLE
    Invoke-Box-Pkg 'install' @('NDK39')
    Installs the NDK39 package
    #>
    param(
        [Parameter(Position=0)]
        [string]$Subcommand,

        [Parameter(Position=1, ValueFromRemainingArguments=$true)]
        [string[]]$Args
    )

    # No subcommand or empty string -> show help
    if ([string]::IsNullOrWhiteSpace($Subcommand)) {
        Show-PkgHelp
        return
    }

    # Route to appropriate handler
    switch ($Subcommand.ToLower()) {
        'install' {
            if ($Args.Count -eq 0) {
                Write-Error "Package name required. Usage: box pkg install <name>"
                return
            }
            
            # Find package definition in config
            $packageName = $Args[0]
            $package = $AllPackages | Where-Object { $_.Name -eq $packageName }
            
            if (-not $package) {
                Write-Error "Package '$packageName' not found in config.psd1"
                Write-Host "Available packages:" -ForegroundColor Gray
                foreach ($pkg in $AllPackages) {
                    Write-Host "  - $($pkg.Name)" -ForegroundColor DarkGray
                }
                return
            }
            
            Process-Package -Item $package
        }

        'list' {
            Show-PackageList
        }

        'validate' {
            # Validate all packages
            Write-Host ""
            Write-Host "Validating package dependencies..." -ForegroundColor Cyan
            Write-Host ""
            
            $hasErrors = $false
            foreach ($pkg in $AllPackages) {
                try {
                    $envs = Validate-PackageDependencies -Package $pkg
                    Write-Host "  ✓ $($pkg.Name): Dependencies satisfied" -ForegroundColor Green
                }
                catch {
                    Write-Host "  ✗ $($pkg.Name): $_" -ForegroundColor Red
                    $hasErrors = $true
                }
            }
            
            Write-Host ""
            if ($hasErrors) {
                Write-Host "Some packages have dependency issues" -ForegroundColor Yellow
            } else {
                Write-Host "All package dependencies validated successfully" -ForegroundColor Green
            }
        }

        'uninstall' {
            if ($Args.Count -eq 0) {
                Write-Error "Package name required. Usage: box pkg uninstall <name>"
                return
            }
            
            $packageName = $Args[0]
            Remove-Package -Name $packageName
        }

        'state' {
            Show-PackageState
        }

        default {
            Write-Error "Unknown pkg subcommand: $Subcommand. Run 'box pkg' for help."
            Show-PkgHelp
        }
    }
}

function Show-PkgHelp {
    <#
    .SYNOPSIS
    Displays help text for pkg subcommands.

    .DESCRIPTION
    Shows available pkg subcommands with descriptions and usage examples.

    .EXAMPLE
    Show-PkgHelp
    #>
    
    Write-Host ""
    Write-Host "Package Management Commands:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  box pkg install <name>    " -NoNewline -ForegroundColor White
    Write-Host "Install specific package" -ForegroundColor Gray
    
    Write-Host "  box pkg list              " -NoNewline -ForegroundColor White
    Write-Host "List installed packages" -ForegroundColor Gray
    
    Write-Host "  box pkg validate          " -NoNewline -ForegroundColor White
    Write-Host "Validate package dependencies" -ForegroundColor Gray
    
    Write-Host "  box pkg uninstall <name>  " -NoNewline -ForegroundColor White
    Write-Host "Remove package" -ForegroundColor Gray
    
    Write-Host "  box pkg state             " -NoNewline -ForegroundColor White
    Write-Host "Display package state" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  box pkg install NDK39" -ForegroundColor DarkGray
    Write-Host "  box pkg list" -ForegroundColor DarkGray
    Write-Host "  box pkg state" -ForegroundColor DarkGray
    Write-Host ""
}
