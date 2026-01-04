# ============================================================================
# Boxer Install Module
# ============================================================================
#
# Handles boxer install command - installing boxes from GitHub URLs

function Install-Box {
    <#
    .SYNOPSIS
    Installs a box from a GitHub URL.

    .PARAMETER BoxUrl
    GitHub repository URL (e.g., https://github.com/user/BoxName)

    .EXAMPLE
    boxer install https://github.com/vbuzzano/AmiDevBox
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$BoxUrl
    )

    Write-Step "Installing box from $BoxUrl..."

    try {
        # Parse GitHub URL to extract owner, repo, branch
        if ($BoxUrl -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$') {
            $Owner = $Matches['owner']
            $Repo = $Matches['repo']
            $BoxName = $Repo
        } else {
            throw "Invalid GitHub URL format. Expected: https://github.com/user/repo"
        }

        Write-Step "Box name: $BoxName"

        # Target directory
        $BoxingDir = "$env:USERPROFILE\Documents\PowerShell\Boxing"
        $BoxesDir = Join-Path $BoxingDir "Boxes"
        $BoxDir = Join-Path $BoxesDir $BoxName

        # Create Boxes directory if needed
        if (-not (Test-Path $BoxesDir)) {
            New-Item -ItemType Directory -Path $BoxesDir -Force | Out-Null
        }

        # Check if box already installed
        if (Test-Path $BoxDir) {
            throw "Box '$BoxName' is already installed at $BoxDir"
        }

        # Create box directory
        New-Item -ItemType Directory -Path $BoxDir -Force | Out-Null
        Write-Success "Created: $BoxDir"

        # Download config.psd1
        Write-Step "Downloading config.psd1..."
        $ConfigUrl = "https://github.com/$Owner/$Repo/raw/main/config.psd1"
        $ConfigPath = Join-Path $BoxDir "config.psd1"
        try {
            Invoke-RestMethod -Uri $ConfigUrl -OutFile $ConfigPath
            Write-Success "Downloaded: config.psd1"
        } catch {
            Write-Host "  Warning: config.psd1 not found (optional)" -ForegroundColor Yellow
        }

        # Download metadata.psd1
        Write-Step "Downloading metadata.psd1..."
        $MetadataUrl = "https://github.com/$Owner/$Repo/raw/main/metadata.psd1"
        $MetadataPath = Join-Path $BoxDir "metadata.psd1"
        try {
            Invoke-RestMethod -Uri $MetadataUrl -OutFile $MetadataPath
            Write-Success "Downloaded: metadata.psd1"
        } catch {
            Write-Host "  Warning: metadata.psd1 not found (optional)" -ForegroundColor Yellow
        }

        # Download tpl/ directory (recursive)
        Write-Step "Downloading templates..."
        $TplDir = Join-Path $BoxDir "tpl"
        New-Item -ItemType Directory -Path $TplDir -Force | Out-Null

        # Use GitHub API to list files in tpl/
        $ApiUrl = "https://api.github.com/repos/$Owner/$Repo/contents/tpl"
        try {
            $TplFiles = Invoke-RestMethod -Uri $ApiUrl
            foreach ($File in $TplFiles) {
                if ($File.type -eq 'file') {
                    $FilePath = Join-Path $TplDir $File.name
                    Invoke-RestMethod -Uri $File.download_url -OutFile $FilePath
                    Write-Success "Downloaded: tpl/$($File.name)"
                }
            }
        } catch {
            Write-Host "  Warning: tpl/ directory not found or empty" -ForegroundColor Yellow
        }

        # Download box.ps1 from repo
        Write-Step "Downloading box.ps1..."
        $BoxUrl = "https://github.com/$Owner/$Repo/raw/main/box.ps1"
        $BoxDest = Join-Path $BoxDir "box.ps1"
        try {
            Invoke-RestMethod -Uri $BoxUrl -OutFile $BoxDest
            Write-Success "Downloaded: box.ps1"
        } catch {
            throw "Failed to download box.ps1: $_"
        }

        # Create .boxer manifest
        Write-Step "Creating manifest..."
        $ManifestPath = Join-Path $BoxDir ".boxer"
        $ManifestContent = @"
Name=$BoxName
Version=0.1.0
Repository=$BoxUrl
"@
        Set-Content -Path $ManifestPath -Value $ManifestContent -Encoding UTF8
        Write-Success "Created: .boxer manifest"

        Write-Success "Box '$BoxName' installed successfully!"
        Write-Host ""
        Write-Host "  Next steps:" -ForegroundColor Cyan
        Write-Host "    boxer init MyProject" -ForegroundColor White

    } catch {
        Write-Host "Box installation failed: $_" -ForegroundColor Red

        # Cleanup on error
        if (Test-Path $BoxDir) {
            Remove-Item -Path $BoxDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

# ============================================================================
# Version Detection Functions
# ============================================================================

function Get-InstalledBoxVersion {
    <#
    .SYNOPSIS
    Gets the version of an installed box.

    .PARAMETER BoxName
    Name of the box to check.

    .RETURNS
    Version string if installed, $null otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$BoxName
    )

    $BoxingDir = "$env:USERPROFILE\Documents\PowerShell\Boxing"
    $MetadataPath = Join-Path $BoxingDir "$BoxName\metadata.psd1"

    if (Test-Path $MetadataPath) {
        try {
            $Metadata = Import-PowerShellDataFile $MetadataPath
            return $Metadata.Version
        } catch {
            Write-Verbose "Failed to read metadata for ${BoxName}: $($_.Exception.Message)"
            return $null
        }
    }

    return $null
}

function Get-RemoteBoxVersion {
    <#
    .SYNOPSIS
    Gets the version from remote metadata content.

    .PARAMETER MetadataContent
    Raw content of metadata.psd1 file.

    .RETURNS
    Version string if found, $null otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MetadataContent
    )

    if ($MetadataContent -match 'Version\s*=\s*"([^"]*)"') {
        return $Matches[1]
    }

    return $null
}

function Compare-BoxVersion {
    <#
    .SYNOPSIS
    Compares two semantic versions.

    .PARAMETER LocalVersion
    Installed version string.

    .PARAMETER RemoteVersion
    Remote version string.

    .RETURNS
    -1 if local > remote, 0 if equal, 1 if remote > local
    #>
    param(
        [string]$LocalVersion,
        [string]$RemoteVersion
    )

    # Not installed → update
    if (-not $LocalVersion) { return 1 }

    # Invalid remote → skip
    if (-not $RemoteVersion) { return -1 }

    try {
        $Local = [version]$LocalVersion
        $Remote = [version]$RemoteVersion

        if ($Remote -gt $Local) { return 1 }   # Remote newer
        if ($Remote -eq $Local) { return 0 }   # Same
        return -1                               # Local newer
    } catch {
        # Fallback to string comparison if version parsing fails
        if ($RemoteVersion -gt $LocalVersion) { return 1 }
        if ($RemoteVersion -eq $LocalVersion) { return 0 }
        return -1
    }
}
