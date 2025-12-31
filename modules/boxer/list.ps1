# ============================================================================
# Boxer List Module
# ============================================================================
#
# Handles boxer list command - listing available boxes

function Invoke-Boxer-List {
    <#
    .SYNOPSIS
    Lists all available Box types.

    .EXAMPLE
    boxer list
    #>
    Write-Host ""
    Write-Host "Available Boxes:" -ForegroundColor Cyan
    Write-Host ""

    $boxersPath = Join-Path (Split-Path -Parent $PSScriptRoot) "boxers"

    if (Test-Path $boxersPath) {
        Get-ChildItem -Path $boxersPath -Directory | ForEach-Object {
            $metadataPath = Join-Path $_.FullName "metadata.psd1"
            if (Test-Path $metadataPath) {
                $metadata = Import-PowerShellDataFile $metadataPath
                Write-Host ("  {0,-20} - {1}" -f $_.Name, $metadata.Description) -ForegroundColor White
            } else {
                Write-Host ("  {0,-20} - {1}" -f $_.Name, "(No description)") -ForegroundColor Gray
            }
        }
    } else {
        Write-Warn "No boxes found in: $boxersPath"
    }

    Write-Host ""
}
