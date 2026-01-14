function New-MgTempRoot {
    param([string]$BasePath = $TestDrive)

    $root = Join-Path $BasePath ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    return $root
}

function New-MgModeModule {
    param(
        [string]$Root,
        [string]$Mode,
        [string]$CommandName,
        [switch]$Override,
        [string]$Body
    )

    $modePascal = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($Mode)
    $relative = $Override.IsPresent ? '.box/modules' : "modules/$Mode"
    $moduleDir = Join-Path $Root $relative
    New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

    $functionName = "Invoke-$modePascal-$CommandName"
    if (-not $Body) {
        $Body = "function $functionName { param([string[]]`$Args) return '$functionName' }"
    }

    $filePath = Join-Path $moduleDir "$CommandName.ps1"
    Set-Content -Path $filePath -Value $Body -Encoding UTF8
    return $filePath
}

function New-MgSharedModule {
    param(
        [string]$Root,
        [string]$ModuleName,
        [string[]]$Commands = @(),
        [string]$Mode = 'Box',
        [switch]$SkipMetadata,
        [string[]]$MissingKeys = @(),
        [string[]]$PrivateFunctions = @()
    )

    $moduleDir = Join-Path $Root "modules/shared/$ModuleName"
    New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

    foreach ($cmd in $Commands) {
        $functionName = "Invoke-$Mode-$cmd"
        $filePath = Join-Path $moduleDir "$cmd.ps1"
        Set-Content -Path $filePath -Value "function $functionName { param([string[]]`$Args) return '$functionName' }" -Encoding UTF8
    }

    if ($SkipMetadata) {
        return $moduleDir
    }

    $metadataLines = @('@{')
    if (-not ($MissingKeys -contains 'ModuleName')) {
        $metadataLines += "    ModuleName = '$ModuleName'"
    }
    if (-not ($MissingKeys -contains 'Commands')) {
        $joinedCommands = ($Commands | ForEach-Object { "'$_'" }) -join ', '
        $metadataLines += "    Commands = @($joinedCommands)"
    }
    if ($PrivateFunctions.Count -gt 0) {
        $joinedPrivates = ($PrivateFunctions | ForEach-Object { "'$_'" }) -join ', '
        $metadataLines += "    PrivateFunctions = @($joinedPrivates)"
    }
    $metadataLines += '}'

    $metaPath = Join-Path $moduleDir 'metadata.psd1'
    Set-Content -Path $metaPath -Value ($metadataLines -join [Environment]::NewLine) -Encoding UTF8
    return $moduleDir
}
