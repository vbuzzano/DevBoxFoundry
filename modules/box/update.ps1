# ============================================================================
# Box Update Module
# ============================================================================
#
# Updates .box/ directory by re-running irm|iex from source repo

function Invoke-Box-Update {
    <#
    .SYNOPSIS
    Updates .box/ to latest version from source

    .DESCRIPTION
    Reads .box/metadata.psd1 to find source repository,
    then executes irm|iex which will update both global Boxing
    and local .box/ if versions differ.

    .EXAMPLE
    box update
    #>
    param()

    Write-Host ""
    Write-Host "Updating box..." -ForegroundColor Cyan
    Write-Host ""

    # Verify we're in a box project
    if (-not $script:BoxDir -or -not (Test-Path $script:BoxDir)) {
        Write-Host "❌ Not in a box project" -ForegroundColor Red
        Write-Host ""
        Write-Host "Run 'boxer init' to create a new project" -ForegroundColor Gray
        return 1
    }

    # Read metadata to get source repository
    $metadataPath = Join-Path $script:BoxDir "metadata.psd1"
    if (-not (Test-Path $metadataPath)) {
        Write-Host "❌ metadata.psd1 not found in .box/" -ForegroundColor Red
        return 1
    }

    try {
        $metadata = Import-PowerShellDataFile -Path $metadataPath
        $sourceRepo = $metadata.SourceRepo

        if (-not $sourceRepo) {
            Write-Host "❌ SourceRepo not defined in metadata.psd1" -ForegroundColor Red
            return 1
        }

        $boxName = $metadata.BoxName
        Write-Host "Box: $boxName" -ForegroundColor Gray
        Write-Host "Source: $sourceRepo" -ForegroundColor Gray
        Write-Host ""

        # Construct download URL
        $url = "https://raw.githubusercontent.com/$sourceRepo/main/box.ps1"

        Write-Host "Downloading and executing update..." -ForegroundColor Cyan
        Write-Host "  $url" -ForegroundColor Gray
        Write-Host ""

        # Execute irm|iex (will trigger Update-LocalBoxIfNeeded in Initialize-Boxing)
        Invoke-RestMethod -Uri $url | Invoke-Expression

        Write-Host ""
        Write-Host "⚠ Restart your PowerShell session to use the updated box" -ForegroundColor Yellow

    } catch {
        Write-Host ""
        Write-Host "❌ Update failed: $_" -ForegroundColor Red
        return 1
    }
}
