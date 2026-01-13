# ============================================================================
# Package List Module
# ============================================================================
#
# Functions for displaying package information.

function Show-PackageList {
    <#
    .SYNOPSIS
    Displays a formatted list of all packages with their status.

    .DESCRIPTION
    Shows a table with package names, environment variables, descriptions,
    and installation status with visual indicators.

    .EXAMPLE
    Show-PackageList
    #>
    Write-Host ""
    Write-Host "Packages:" -ForegroundColor Cyan
    Write-Host ""

    $state = Load-State

    # Table columns
    $colName = 20
    $colEnv = 18
    $colValue = 35
    $colStatus = 9

    Write-Host ("  {0,-$colName} {1,-$colEnv} {2,-$colValue} {3}" -f "NAME", "ENV VARS", "DESCRIPTION", "INSTALLED") -ForegroundColor DarkGray
    Write-Host ("  {0,-$colName} {1,-$colEnv} {2,-$colValue} {3}" -f ("-" * $colName), ("-" * $colEnv), ("-" * $colValue), ("-" * $colStatus)) -ForegroundColor DarkGray

    foreach ($item in $AllPackages) {
        $name = $item.Name
        $pkgState = if ($state.packages.ContainsKey($name)) { $state.packages[$name] } else { $null }

        # Get ENV vars (from state if installed, from rules if not)
        $envVars = @{}
        if ($pkgState -and $pkgState.envs) {
            $envVars = $pkgState.envs
        } elseif ($item.Extract) {
            foreach ($rule in $item.Extract) {
                $parsed = Parse-ExtractRule $rule
                if ($parsed -and $parsed.EnvVar) {
                    $envVars[$parsed.EnvVar] = $null
                }
            }
        }

        # Status indicator (last column)
        $isInstalled = $pkgState -and $pkgState.installed
        $isManual = $pkgState -and -not $pkgState.installed
        $hasEnvVars = $envVars.Count -gt 0
        $statusMark = if ($isInstalled) { [char]0x1F60A } elseif ($isManual) { [char]0x1F4E6 } else { "" }
        $statusColor = if ($isInstalled) { "Green" } elseif ($isManual) { "Yellow" } else { "DarkGray" }

        # First line: package name + first ENV or description
        $firstEnv = $envVars.Keys | Select-Object -First 1

        Write-Host ("  {0,-$colName}" -f $name) -ForegroundColor White -NoNewline

        if ($firstEnv) {
            $firstValue = if ($envVars[$firstEnv]) { $envVars[$firstEnv] } else { $item.Description }
            $valueColor = if ($envVars[$firstEnv]) { "Gray" } else { "DarkGray" }
            Write-Host (" {0,-$colEnv}" -f $firstEnv) -ForegroundColor Cyan -NoNewline
            Write-Host (" {0,-$colValue}" -f $firstValue) -ForegroundColor $valueColor -NoNewline
        } else {
            Write-Host (" {0,-$colEnv} {1,-$colValue}" -f "", $item.Description) -ForegroundColor DarkGray -NoNewline
        }
        Write-Host $statusMark -ForegroundColor $statusColor

        # Additional ENV vars (skip first)
        $remaining = $envVars.Keys | Select-Object -Skip 1
        foreach ($envName in $remaining) {
            $envValue = if ($envVars[$envName]) { $envVars[$envName] } else { $item.Description }
            $valueColor = if ($envVars[$envName]) { "Gray" } else { "DarkGray" }

            Write-Host ("  {0,-$colName}" -f "") -NoNewline
            Write-Host (" {0,-$colEnv}" -f $envName) -ForegroundColor Cyan -NoNewline
            Write-Host (" {0,-$colValue}" -f $envValue) -ForegroundColor $valueColor
        }
    }

    Write-Host ""
}
