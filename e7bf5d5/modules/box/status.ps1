# ============================================================================
# Box Status Module
# ============================================================================
#
# Handles box status command - showing project status

function Invoke-Box-Status {
    <#
    .SYNOPSIS
    Displays project status and configuration.

    .EXAMPLE
    box status
    #>

    Write-Host ""
    Write-Host "Project Status" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host ""

    # Project info
    if ($Config.Project) {
        Write-Host "Project:" -ForegroundColor White
        Write-Host ("  Name:        {0}" -f $Config.Project.Name) -ForegroundColor Gray
        Write-Host ("  Description: {0}" -f $Config.Project.Description) -ForegroundColor Gray
        Write-Host ("  Version:     {0}" -f $Config.Project.Version) -ForegroundColor Gray
        Write-Host ""
    }

    # Packages status
    $state = Load-State
    $installedCount = 0
    $manualCount = 0

    if ($state.packages) {
        foreach ($pkgName in $state.packages.Keys) {
            $pkg = $state.packages[$pkgName]
            if ($pkg.installed) {
                $installedCount++
            } else {
                $manualCount++
            }
        }
    }

    Write-Host "Packages:" -ForegroundColor White
    Write-Host ("  Installed:   {0}" -f $installedCount) -ForegroundColor Green
    Write-Host ("  Manual:      {0}" -f $manualCount) -ForegroundColor Yellow
    Write-Host ("  Total:       {0}" -f ($installedCount + $manualCount)) -ForegroundColor Gray
    Write-Host ""

    # Directories
    Write-Host "Directories:" -ForegroundColor White
    Write-Host ("  Base:        {0}" -f $BaseDir) -ForegroundColor Gray
    Write-Host ("  Vendor:      {0}" -f $VendorDir) -ForegroundColor Gray
    Write-Host ("  Temp:        {0}" -f $TempDir) -ForegroundColor Gray
    Write-Host ""
}
