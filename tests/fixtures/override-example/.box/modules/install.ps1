# ============================================================================
# Example Box Override Module - Install
# ============================================================================
#
# This is an example of box-specific module override.
# When placed in .box/modules/install.ps1, this will replace the core
# install module for this box.
#
# Use case: Custom package installation logic specific to this box

function Invoke-Box-Install {
    <#
    .SYNOPSIS
    Custom install logic for this box.

    .DESCRIPTION
    This overrides the core install command with box-specific behavior.
    Example: Install packages from a custom source, validate specific
    dependencies, or integrate with proprietary tooling.
    #>
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Arguments
    )

    Write-Host ""
    Write-Host "=== CUSTOM INSTALL MODULE (Override) ===" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "This is a box-specific install implementation." -ForegroundColor Cyan
    Write-Host "Arguments: $($Arguments -join ', ')" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Custom logic would go here:" -ForegroundColor Yellow
    Write-Host "  - Validate box-specific dependencies" -ForegroundColor White
    Write-Host "  - Download from custom package source" -ForegroundColor White
    Write-Host "  - Run proprietary tooling" -ForegroundColor White
    Write-Host ""
    Write-Host "✓ Custom install complete" -ForegroundColor Green
    Write-Host ""
}
