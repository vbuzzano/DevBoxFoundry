# Box Info Command
# Display detailed information for current box workspace

function Invoke-Box-Info {
    Write-Host ""
    Write-Host "Box Workspace Information" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host ""

    # Detect box.ps1 version (from embedded variable)
    $BoxVersion = if ($script:BoxerVersion) {
        $script:BoxerVersion
    } else {
        "Unknown"
    }

    Write-Host "Box Runtime:" -ForegroundColor Yellow
    Write-Host "  Version: $BoxVersion" -ForegroundColor Gray
    Write-Host ""

    # Read box metadata
    if ($script:BoxDir) {
        $metadataFile = Join-Path $script:BoxDir "metadata.psd1"

        if (Test-Path $metadataFile) {
            try {
                $metadata = Import-PowerShellDataFile -Path $metadataFile

                Write-Host "Box Information:" -ForegroundColor Yellow
                Write-Host "  Name:         $($metadata.BoxName)" -ForegroundColor Gray
                Write-Host "  Version:      $($metadata.Version)" -ForegroundColor Gray

                if ($metadata.BoxerVersion) {
                    Write-Host "  Core Version: $($metadata.BoxerVersion)" -ForegroundColor Gray
                }

                if ($metadata.BuildDate) {
                    Write-Host "  Build Date:   $($metadata.BuildDate)" -ForegroundColor Gray
                }

                if ($metadata.BoxType) {
                    Write-Host "  Type:         $($metadata.BoxType)" -ForegroundColor Gray
                }

                if ($metadata.Author) {
                    Write-Host "  Author:       $($metadata.Author)" -ForegroundColor Gray
                }

                if ($metadata.Tags) {
                    Write-Host "  Tags:         $($metadata.Tags -join ', ')" -ForegroundColor Gray
                }

                Write-Host ""
            } catch {
                Write-Host "Error reading metadata: $_" -ForegroundColor Red
                Write-Host ""
            }
        } else {
            Write-Host "No metadata.psd1 found in .box directory" -ForegroundColor Yellow
            Write-Host ""
        }
    }

    # Workspace info
    if ($script:BaseDir) {
        Write-Host "Workspace:" -ForegroundColor Yellow
        Write-Host "  Location: $script:BaseDir" -ForegroundColor Gray
        Write-Host ""
    }
}
