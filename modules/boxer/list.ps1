# ============================================================================
# Boxer List Module
# ============================================================================
#
# Handles boxer list command - listing installed boxes from user installation directory

function Invoke-Boxer-List {
    <#
    .SYNOPSIS
    Lists all installed Box types from ~/Documents/PowerShell/Boxing/Boxes/.

    .DESCRIPTION
    Displays boxes that are actually installed on the user's system,
    not development boxes in the repository.

    .EXAMPLE
    boxer list
    #>
    Write-Host ""
    Write-Host "Installed Boxes:" -ForegroundColor Cyan
    Write-Host ""

    # Read from user installation directory, not repository
    $boxesPath = Join-Path $env:USERPROFILE "Documents\PowerShell\Boxing\Boxes"

    if (-not (Test-Path $boxesPath)) {
        Write-Host "  No boxes installed yet." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  To install a box, run:" -ForegroundColor Gray
        Write-Host "    boxer install <box-name-or-url>" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Examples:" -ForegroundColor Gray
        Write-Host "    boxer install AmiDevBox" -ForegroundColor DarkGray
        Write-Host "    boxer install https://github.com/user/MyBox" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    $boxes = Get-ChildItem -Path $boxesPath -Directory -ErrorAction SilentlyContinue

    if (-not $boxes -or @($boxes).Count -eq 0) {
        Write-Host "  No boxes installed yet." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  To install a box, run:" -ForegroundColor Gray
        Write-Host "    boxer install <box-name-or-url>" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    # Display installed boxes with version and description
    $hasValidBoxes = $false

    foreach ($boxDir in $boxes) {
        $metadataPath = Join-Path $boxDir.FullName "metadata.psd1"

        if (Test-Path $metadataPath) {
            try {
                $metadata = Import-PowerShellDataFile $metadataPath
                $version = if ($metadata.ContainsKey('Version')) { "v$($metadata.Version)" } else { "(no version)" }
                $description = if ($metadata.ContainsKey('Description')) { $metadata.Description } else { "(no description)" }

                Write-Host ("  {0,-20} {1,-12} - {2}" -f $boxDir.Name, $version, $description) -ForegroundColor White
                $hasValidBoxes = $true
            }
            catch {
                # Corrupted metadata.psd1 - show warning but continue
                Write-Host ("  {0,-20} " -f $boxDir.Name) -NoNewline -ForegroundColor Yellow
                Write-Host "(corrupted metadata)" -ForegroundColor DarkYellow
                Write-Warning "Failed to read metadata for $($boxDir.Name): $_"
            }
        }
        else {
            # No metadata - still show the box
            Write-Host ("  {0,-20} " -f $boxDir.Name) -NoNewline -ForegroundColor Gray
            Write-Host "(no metadata)" -ForegroundColor DarkGray
            $hasValidBoxes = $true
        }
    }

    if (-not $hasValidBoxes) {
        Write-Host "  No valid boxes found in: $boxesPath" -ForegroundColor Yellow
    }

    Write-Host ""
}
