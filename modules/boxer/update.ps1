# Boxer Update Command
# Updates a box project's .box/ directory

function Invoke-Boxer-Update {
    <#
    .SYNOPSIS
    Updates a box project to the latest version

    .DESCRIPTION
    Navigates to the specified project directory (or current directory)
    and executes 'box update' which triggers irm|iex from the box's source repo.

    .PARAMETER Path
    Path to the box project directory. Defaults to current directory.

    .EXAMPLE
    boxer update

    .EXAMPLE
    boxer update C:\Projects\MyProject
    #>
    param(
        [Parameter(Position=0)]
        [string]$Path = "."
    )

    # Resolve to absolute path
    $targetPath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue

    if (-not $targetPath) {
        Write-Host "❌ Path not found: $Path" -ForegroundColor Red
        return 1
    }

    # Check if .box exists
    $boxDir = Join-Path $targetPath ".box"
    if (-not (Test-Path $boxDir)) {
        Write-Host "❌ Not a box project: $targetPath" -ForegroundColor Red
        Write-Host ""
        Write-Host "No .box/ directory found" -ForegroundColor Gray
        return 1
    }

    # Save current location
    $originalLocation = Get-Location

    try {
        # Navigate to project
        Set-Location $targetPath

        # Check if box.ps1 exists in .box
        $boxScript = Join-Path $boxDir "box.ps1"
        if (-not (Test-Path $boxScript)) {
            Write-Host "❌ Invalid box project: box.ps1 not found in .box/" -ForegroundColor Red
            return 1
        }

        # Execute box update
        & $boxScript update

    } finally {
        # Restore location
        Set-Location $originalLocation
    }
}
