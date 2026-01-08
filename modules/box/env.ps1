# ============================================================================
# Box Env Module - Main Dispatcher
# ============================================================================
#
# Handles box env command with subcommands (list, load, replace, update)

function Invoke-Box-Env {
    <#
    .SYNOPSIS
    Manages environment variables for the project.

    .PARAMETER Sub
    Subcommand to execute: list, load, replace, update

    .EXAMPLE
    box env list
    box env load
    box env replace KEY=VALUE
    box env update
    #>
    
    param(
        [Parameter(Position=0)]
        [string]$Sub
    )

    # Default to list if no subcommand
    if (-not $Sub) {
        $Sub = 'list'
    }

    # Dispatch to appropriate subcommand
    switch ($Sub.ToLower()) {
        'list' {
            Invoke-Box-Env-List
        }
        'load' {
            Invoke-Box-Env-Load
        }
        'replace' {
            Invoke-Box-Env-Replace -KeyValue $args
        }
        'update' {
            Invoke-Box-Env-Update
        }
        default {
            Write-Host "Unknown env subcommand: $Sub" -ForegroundColor Red
            Write-Host "Available: list, load, replace, update" -ForegroundColor Gray
            exit 1
        }
    }
}
