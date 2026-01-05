# ============================================================================
# Boxer Init Module
# ============================================================================
#
# Handles boxer init command - creating new Box projects

function Get-InstalledVersion {
    <#
    .SYNOPSIS
    Gets the version from a metadata.psd1 file.

    .PARAMETER MetadataPath
    Path to metadata.psd1 file

    .OUTPUTS
    Version string (e.g., "1.0.0") or $null if not found
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MetadataPath
    )

    if (-not (Test-Path $MetadataPath)) {
        return $null
    }

    try {
        $metadata = Import-PowerShellDataFile -Path $MetadataPath -ErrorAction Stop
        return $metadata.Version
    } catch {
        return $null
    }
}

function Compare-Version {
    <#
    .SYNOPSIS
    Compares two version strings.

    .OUTPUTS
    -1 if v1 < v2, 0 if equal, 1 if v1 > v2
    #>
    param(
        [string]$Version1,
        [string]$Version2
    )

    try {
        $v1 = [version]$Version1
        $v2 = [version]$Version2
        return $v1.CompareTo($v2)
    } catch {
        # Fallback to string comparison
        return [string]::Compare($Version1, $Version2)
    }
}

function Invoke-Boxer-Init {
    <#
    .SYNOPSIS
    Creates a new Box project with full structure.

    .PARAMETER ProjectName
    Name of the project to create

    .PARAMETER Description
    Optional project description

    .EXAMPLE
    boxer init MyProject "My awesome project"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectName,
        [string]$Description = ""
    )

    # Sanitize project name
    $SafeName = $ProjectName -replace '[^\w\-]', '-'
    $TargetDir = Join-Path (Get-Location) $SafeName

    # Check if directory exists
    if (Test-Path $TargetDir) {
        Write-Err "Directory '$SafeName' already exists"
        return
    }

    Write-Step "Creating project: $ProjectName"

    try {
        # Create project directory
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

        # Create .box directory
        $BoxPath = Join-Path $TargetDir ".box"
        New-Item -ItemType Directory -Path $BoxPath -Force | Out-Null

        # Copy box.ps1 and boxing.ps1
        $LocalBoxPath = Join-Path (Split-Path -Parent $PSScriptRoot) "boxing.ps1"
        if (Test-Path $LocalBoxPath) {
            Copy-Item $LocalBoxPath (Join-Path $BoxPath "boxing.ps1") -Force
            Write-Success "Copied: boxing.ps1"
        }

        # Copy config.psd1
        $LocalConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) "config.psd1"
        if (Test-Path $LocalConfigPath) {
            Copy-Item $LocalConfigPath (Join-Path $BoxPath "config.psd1") -Force
            Write-Success "Copied: config.psd1"
        }

        # Create basic structure
        @('src', 'docs', 'scripts', 'vendor') | ForEach-Object {
            New-Item -ItemType Directory -Path (Join-Path $TargetDir $_) -Force | Out-Null
        }

        Write-Success "Project created: $SafeName"
        Write-Host "  Next steps:" -ForegroundColor Cyan
        Write-Host "    cd $SafeName" -ForegroundColor White
        Write-Host "    box install" -ForegroundColor White

    } catch {
        Write-Err "Project creation failed: $_"
        if (Test-Path $TargetDir) {
            Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-BoxingSystem {
    <#
    .SYNOPSIS
    Installs Boxing system globally (boxer.ps1 and box.ps1).

    .DESCRIPTION
    Sets up Boxing for global use by:
    - Creating Scripts directory in PowerShell folder
    - Copying boxer.ps1 and box.ps1 to Scripts
    - Creating Boxing directory for box storage
    - Modifying PowerShell profile with boxer and box functions
    - Avoiding duplication if already installed

    .EXAMPLE
    Install-BoxingSystem
    #>

    Write-Step "Installing Boxing system globally..."

    try {
        # Paths
        $BoxingDir = "$env:USERPROFILE\Documents\PowerShell\Boxing"
        $ProfilePath = $PROFILE.CurrentUserAllHosts

        # Fallback if PROFILE is not set (rare but possible in some contexts)
        if (-not $ProfilePath) {
            $ProfilePath = "$env:USERPROFILE\Documents\PowerShell\profile.ps1"
        }

        # Create Boxing directory
        if (-not (Test-Path $BoxingDir)) {
            Write-Step "Creating Boxing directory..."
            New-Item -ItemType Directory -Path $BoxingDir -Force | Out-Null
            Write-Success "Created: $BoxingDir"
        }

        # Create Boxes subdirectory
        $BoxesDir = Join-Path $BoxingDir "Boxes"
        if (-not (Test-Path $BoxesDir)) {
            Write-Step "Creating Boxes directory..."
            New-Item -ItemType Directory -Path $BoxesDir -Force | Out-Null
            Write-Success "Created: $BoxesDir"
        }

        # Copy boxer.ps1 to Boxing directory (self-installation pattern)
        $BoxerPath = Join-Path $BoxingDir "boxer.ps1"
        $BoxerMetadataPath = Join-Path $BoxingDir "boxer-metadata.psd1"
        $BoxerAlreadyInstalled = Test-Path $BoxerPath

        # Always set source repo for AmiDevBox release (hardcoded in dist build)
        $SourceRepo = "AmiDevBox"

        # Get versions for comparison
        $InstalledVersion = Get-InstalledVersion -MetadataPath $BoxerMetadataPath

        # Get new version via core API (works in all modes)
        $NewVersion = Get-BoxerVersion

        # Determine if update is needed
        $NeedsUpdate = $false
        if (-not $BoxerAlreadyInstalled) {
            $NeedsUpdate = $true
            Write-Step "Installing boxer.ps1..."
        } elseif ($InstalledVersion -and (Compare-Version -Version1 $NewVersion -Version2 $InstalledVersion) -gt 0) {
            $NeedsUpdate = $true
            Write-Step "Updating boxer.ps1 ($InstalledVersion → $NewVersion)..."
        } else {
            Write-Success "boxer.ps1 already up-to-date (v$InstalledVersion)"
        }

        if ($NeedsUpdate) {
            # If executed via irm|iex, $PSCommandPath is empty - download from GitHub
            if (-not $PSCommandPath -or -not (Test-Path $PSCommandPath)) {
                $boxerUrl = "https://raw.githubusercontent.com/vbuzzano/AmiDevBox/main/boxer.ps1"

                try {
                    Invoke-RestMethod -Uri $boxerUrl -OutFile $BoxerPath
                    Write-Success "Downloaded: boxer.ps1"
                } catch {
                    throw "Failed to download boxer.ps1 from $boxerUrl : $_"
                }
            } else {
                # Local installation (running from file)
                Copy-Item -Path $PSCommandPath -Destination $BoxerPath -Force
                Write-Success "Installed: boxer.ps1"
            }

            # Save metadata with version
            $BoxerMetadata = @"
@{
    Version = "$NewVersion"
    InstallDate = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}
"@
            Set-Content -Path $BoxerMetadataPath -Value $BoxerMetadata -Encoding UTF8
        }        # Modify PowerShell profile
        Write-Step "Configuring PowerShell profile..."

        # Create profile directory if needed
        $ProfileDir = Split-Path $ProfilePath -Parent
        if (-not (Test-Path $ProfileDir)) {
            New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
        }

        # Read existing profile or create empty
        $ProfileContent = ""
        if (Test-Path $ProfilePath) {
            $ProfileContent = Get-Content $ProfilePath -Raw
        }

        # Check if #region boxing already exists
        if ($ProfileContent -match '#region boxing') {
            Write-Success "Profile already configured (skipping)"
        } else {
            # Add Boxing region to profile (lightweight dot-source approach)
            $BoxingRegion = @"

#region boxing
`$boxingInit = "`$env:USERPROFILE\Documents\PowerShell\Boxing\init.ps1"
if (Test-Path `$boxingInit) {
    . `$boxingInit
}
#endregion boxing
"@

            # Append to profile
            $ProfileContent += $BoxingRegion
            Set-Content -Path $ProfilePath -Value $ProfileContent -Encoding UTF8
            Write-Success "Profile configured with Boxing loader"
        }

        # Install box if this is a box repository (not Boxing main repo)
        if ($SourceRepo) {
            Install-CurrentBox -BoxName $SourceRepo -BoxingDir $BoxingDir
        }

        # Create init.ps1 in Boxing directory for easy session loading
        Write-Step "Creating session loader..."
        $InitScript = @"
# Boxing Session Loader
# Run this to load boxer and box functions in current session without restarting PowerShell
#
# Usage: . `$env:USERPROFILE\Documents\PowerShell\Boxing\init.ps1

function boxer {
    `$boxerPath = "`$env:USERPROFILE\Documents\PowerShell\Boxing\boxer.ps1"
    if (Test-Path `$boxerPath) {
        & `$boxerPath @args
    } else {
        Write-Host "Error: boxer.ps1 not found at `$boxerPath" -ForegroundColor Red
    }
}

function box {
    `$boxScript = `$null
    `$current = (Get-Location).Path

    while (`$current -ne [System.IO.Path]::GetPathRoot(`$current)) {
        `$testPath = Join-Path `$current ".box\box.ps1"
        if (Test-Path `$testPath) {
            `$boxScript = `$testPath
            break
        }
        `$parent = Split-Path `$current -Parent
        if (-not `$parent) { break }
        `$current = `$parent
    }

    if (-not `$boxScript) {
        Write-Host "❌ No box project found" -ForegroundColor Red
        Write-Host ""
        Write-Host "Create a new project:" -ForegroundColor Cyan
        Write-Host "  boxer init MyProject" -ForegroundColor White
        return
    }

    & `$boxScript @args
}

Write-Host "✓ Boxing functions loaded (boxer, box)" -ForegroundColor Green
"@
        $InitPath = Join-Path $BoxingDir "init.ps1"
        Set-Content -Path $InitPath -Value $InitScript -Encoding UTF8
        Write-Success "Created: init.ps1"

        # Load functions in current session via global scope
        Write-Step "Loading functions in current session..."

        $global:function:boxer = {
            $boxerPath = "$env:USERPROFILE\Documents\PowerShell\Boxing\boxer.ps1"
            if (Test-Path $boxerPath) {
                & $boxerPath @args
            } else {
                Write-Host "Error: boxer.ps1 not found at $boxerPath" -ForegroundColor Red
            }
        }

        $global:function:box = {
            $boxScript = $null
            $current = (Get-Location).Path

            while ($current -ne [System.IO.Path]::GetPathRoot($current)) {
                $testPath = Join-Path $current ".box\box.ps1"
                if (Test-Path $testPath) {
                    $boxScript = $testPath
                    break
                }
                $parent = Split-Path $current -Parent
                if (-not $parent) { break }
                $current = $parent
            }

            if (-not $boxScript) {
                Write-Host "❌ No box project found" -ForegroundColor Red
                Write-Host ""
                Write-Host "Create a new project:" -ForegroundColor Cyan
                Write-Host "  boxer init MyProject" -ForegroundColor White
                return
            }

            & $boxScript @args
        }

        # Only show "functions loaded" message on first install
        if (-not $BoxerAlreadyInstalled) {
            Write-Success "✓ Boxing functions loaded (boxer, box)"
        }

        Write-Success "Boxing system installed successfully!"
        Write-Host ""
        Write-Host "  Ready to use! Try:" -ForegroundColor Cyan
        Write-Host "    boxer init MyProject" -ForegroundColor White
        Write-Host ""
        Write-Host "  💡 Recommended: Restart PowerShell for permanent installation" -ForegroundColor Yellow
        Write-Host "     (functions work now, but restart ensures they persist)" -ForegroundColor DarkGray

    } catch {
        Write-Host "Installation failed: $_" -ForegroundColor Red
        throw
    }
}

function Install-CurrentBox {
    <#
    .SYNOPSIS
    Installs the current box from its GitHub repository.

    .PARAMETER BoxName
    Name of the box to install (e.g., AmiDevBox)

    .PARAMETER BoxingDir
    Path to Boxing directory
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$BoxName,

        [Parameter(Mandatory=$true)]
        [string]$BoxingDir
    )

    Write-Step "Installing $BoxName box..."

    try {
        $BoxesDir = Join-Path $BoxingDir "Boxes"
        $BoxDir = Join-Path $BoxesDir $BoxName
        $BoxMetadataPath = Join-Path $BoxDir "metadata.psd1"

        # Base URL for downloads
        $BaseUrl = "https://raw.githubusercontent.com/vbuzzano/$BoxName/main"

        # Get installed version
        $InstalledVersion = Get-InstalledVersion -MetadataPath $BoxMetadataPath

        # Get remote version from GitHub
        $RemoteVersion = $null
        try {
            $RemoteMetadataUrl = "$BaseUrl/metadata.psd1"
            $RemoteMetadataContent = Invoke-RestMethod -Uri $RemoteMetadataUrl -ErrorAction Stop

            # Parse version from downloaded content
            if ($RemoteMetadataContent -match 'Version\s*=\s*"([^"]+)"') {
                $RemoteVersion = $Matches[1]
            }
        } catch {
            Write-Warn "Could not fetch remote version, proceeding with install"
        }

        # Determine if update is needed
        $NeedsUpdate = $false
        if (-not (Test-Path $BoxDir)) {
            $NeedsUpdate = $true
            Write-Step "Installing $BoxName..."
        } elseif ($RemoteVersion -and $InstalledVersion -and (Compare-Version -Version1 $RemoteVersion -Version2 $InstalledVersion) -gt 0) {
            $NeedsUpdate = $true
            Write-Step "Updating $BoxName ($InstalledVersion → $RemoteVersion)..."
        } elseif ($RemoteVersion -and $InstalledVersion -and (Compare-Version -Version1 $RemoteVersion -Version2 $InstalledVersion) -eq 0) {
            Write-Success "$BoxName already up-to-date (v$InstalledVersion)"
            return
        } else {
            Write-Success "$BoxName already installed (v$InstalledVersion)"
            return
        }

        if (-not $NeedsUpdate) {
            return
        }

        # Create box directory
        New-Item -ItemType Directory -Path $BoxDir -Force | Out-Null

        # Download box.ps1
        Write-Step "Downloading box.ps1..."
        try {
            Invoke-RestMethod -Uri "$BaseUrl/box.ps1" -OutFile (Join-Path $BoxDir "box.ps1")
            Write-Success "Downloaded: box.ps1"
        } catch {
            throw "Failed to download box.ps1: $_"
        }

        # Download config.psd1
        Write-Step "Downloading config.psd1..."
        try {
            Invoke-RestMethod -Uri "$BaseUrl/config.psd1" -OutFile (Join-Path $BoxDir "config.psd1")
            Write-Success "Downloaded: config.psd1"
        } catch {
            Write-Warn "config.psd1 not found (optional)"
        }

        # Download metadata.psd1
        Write-Step "Downloading metadata.psd1..."
        try {
            Invoke-RestMethod -Uri "$BaseUrl/metadata.psd1" -OutFile (Join-Path $BoxDir "metadata.psd1")
            Write-Success "Downloaded: metadata.psd1"
        } catch {
            Write-Warn "metadata.psd1 not found (optional)"
        }

        # Download env.ps1 (environment configuration)
        Write-Step "Downloading env.ps1..."
        try {
            Invoke-RestMethod -Uri "$BaseUrl/env.ps1" -OutFile (Join-Path $BoxDir "env.ps1")
            Write-Success "Downloaded: env.ps1"
        } catch {
            Write-Warn "env.ps1 not found (optional)"
        }

        # Download tpl/ directory (FILES ONLY, no subdirectories)
        Write-Step "Downloading templates..."
        $TplDir = Join-Path $BoxDir "tpl"
        New-Item -ItemType Directory -Path $TplDir -Force | Out-Null

        # Use GitHub API to list tpl/ contents
        try {
            $ApiUrl = "https://api.github.com/repos/vbuzzano/$BoxName/contents/tpl"
            $TplFiles = Invoke-RestMethod -Uri $ApiUrl

            foreach ($File in $TplFiles) {
                # Download ONLY files at root of tpl/, skip directories (docs/, src/, etc.)
                if ($File.type -eq 'file') {
                    $FilePath = Join-Path $TplDir $File.name
                    Invoke-RestMethod -Uri $File.download_url -OutFile $FilePath
                    Write-Success "Downloaded: tpl/$($File.name)"
                }
            }
        } catch {
            Write-Warn "tpl/ directory not found or empty"
        }

        Write-Success "$BoxName box installed successfully!"

    } catch {
        Write-Err "Box installation failed: $_"

        # Cleanup on error
        if (Test-Path $BoxDir) {
            Remove-Item -Path $BoxDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

