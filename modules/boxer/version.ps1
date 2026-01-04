# Boxer Version Command
# Display version information for boxer and installed boxes

function Invoke-Boxer-Version {
    Write-Host ""
    Write-Host "Boxing System Version Information" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host ""

    # Detect version (prefer embedded variable, fallback to file parsing)
    $BoxerVersion = if ($script:BoxerVersion) {
        $script:BoxerVersion
    } else {
        "Unknown"
    }

    Write-Host "Boxer:" -ForegroundColor Yellow
    Write-Host "  Version:  $BoxerVersion" -ForegroundColor Gray

    # Check installed location
    $boxerPath = "$env:USERPROFILE\Documents\PowerShell\Boxing\boxer.ps1"
    if (Test-Path $boxerPath) {
        $installedContent = Get-Content $boxerPath -Raw -ErrorAction SilentlyContinue
        if ($installedContent -match 'Version:\s*(\d+\.\d+\.\d+)') {
            $installedVersion = $Matches[1]
            Write-Host "  Installed: $installedVersion" -ForegroundColor Gray

            if ($installedVersion -ne $BoxerVersion) {
                Write-Host "  Status:   " -NoNewline -ForegroundColor Gray
                Write-Host "Update available" -ForegroundColor Yellow
            } else {
                Write-Host "  Status:   " -NoNewline -ForegroundColor Gray
                Write-Host "Up to date" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "  Installed: Not installed" -ForegroundColor Gray
    }

    Write-Host ""

    # List installed boxes
    $boxesDir = "$env:USERPROFILE\Documents\PowerShell\Boxing\Boxes"
    if (Test-Path $boxesDir) {
        $boxes = @(Get-ChildItem -Path $boxesDir -Directory)

        if ($boxes.Count -gt 0) {
            Write-Host "Installed Boxes:" -ForegroundColor Yellow

            foreach ($box in $boxes) {
                $metadataFile = Join-Path $box.FullName "metadata.psd1"

                if (Test-Path $metadataFile) {
                    try {
                        $metadata = Import-PowerShellDataFile -Path $metadataFile
                        $boxName = $metadata.BoxName
                        $boxVersion = $metadata.Version
                        $boxerVersion = if ($metadata.BoxerVersion) { $metadata.BoxerVersion } else { "Unknown" }

                        Write-Host "  $boxName" -ForegroundColor Cyan
                        Write-Host "    Version:      $boxVersion" -ForegroundColor Gray
                        Write-Host "    Core:         $boxerVersion" -ForegroundColor Gray
                        if ($metadata.BuildDate) {
                            Write-Host "    Build Date:   $($metadata.BuildDate)" -ForegroundColor Gray
                        }
                    } catch {
                        Write-Host "  $($box.Name)" -ForegroundColor Cyan
                        Write-Host "    Error reading metadata" -ForegroundColor Red
                    }
                } else {
                    Write-Host "  $($box.Name)" -ForegroundColor Cyan
                    Write-Host "    No metadata found" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "Installed Boxes: None" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Installed Boxes: None" -ForegroundColor Yellow
    }

    Write-Host ""
}
