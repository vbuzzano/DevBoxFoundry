function Test-PackageInstalled {
    param([hashtable]$Package)

    if (-not $Package -or -not $Package.Name) {
        return @{ Installed = $false; Source = $null; Path = $null }
    }

    $state = Load-State
    if ($state.packages.ContainsKey($Package.Name)) {
        $pkgState = $state.packages[$Package.Name]
        return @{ Installed = ($pkgState.installed -eq $true); Source = 'state'; Path = $global:VendorDir }
    }

    return @{ Installed = $false; Source = $null; Path = $null }
}
