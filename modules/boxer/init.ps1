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

function Sanitize-ProjectName {
    <#
    .SYNOPSIS
    Sanitizes a project name to make it a valid directory name.

    .PARAMETER Name
    The project name to sanitize

    .OUTPUTS
    Sanitized project name suitable for directory creation
    #>
    param([string]$Name)

    # Remove/replace invalid characters for directory names
    $sanitized = $Name -replace '[/\\()^''":\[\]<>|?*]', '-'
    # Convert to lowercase
    $sanitized = $sanitized.ToLower()
    # Remove trailing dots and spaces
    $sanitized = $sanitized -replace '[\s.]+$', ''
    # Remove leading/trailing dashes
    $sanitized = $sanitized -replace '^-+|-+$', ''
    # Keep only alphanumeric, dash, dot, underscore, plus
    $sanitized = $sanitized -replace '[^a-z0-9.\-_+]', '-'

    return $sanitized
}

function Get-InstalledBoxes {
    <#
    .SYNOPSIS
    Gets list of installed boxes from Boxing directory.

    .OUTPUTS
    Array of box names (directory names in Boxing\Boxes\)
    #>

    $BoxingDir = "$env:USERPROFILE\Documents\PowerShell\Boxing"
    $BoxesDir = Join-Path $BoxingDir "Boxes"

    if (-not (Test-Path $BoxesDir)) {
        return @()
    }

    $boxes = Get-ChildItem -Path $BoxesDir -Directory | Select-Object -ExpandProperty Name
    return $boxes
}

# Rollback tracking for error recovery
$Script:CreatedItems = @()

function Track-Creation {
    param([string]$Path, [string]$Type = 'file')
    $Script:CreatedItems += @{ Path = $Path; Type = $Type }
}

function Rollback-Creation {
    Write-Host ''
    Write-Step 'Rolling back changes...'

    # Reverse order (newest first)
    for ($i = $Script:CreatedItems.Count - 1; $i -ge 0; $i--) {
        $item = $Script:CreatedItems[$i]
        if (Test-Path $item.Path) {
            try {
                Remove-Item $item.Path -Recurse -Force -ErrorAction SilentlyContinue
                Write-Success "Removed: $($item.Path)"
            }
            catch {
                Write-Host "  ⚠ Could not remove: $($item.Path)" -ForegroundColor Yellow
            }
        }
    }

    $Script:CreatedItems = @()
}

function Invoke-Boxer-Init {
    <#
    .SYNOPSIS
    Creates a new Box project with full structure.

    .PARAMETER Name
    Name of the project to create (optional - will prompt if not provided)

    .PARAMETER Path
    Custom path where to create the project (optional - uses Name in current dir if not provided)

    .PARAMETER Box
    Which box to use (optional - auto-detects if only one installed, prompts if multiple)

    .EXAMPLE
    boxer init
    # Prompts for name, uses current directory, auto-selects box

    .EXAMPLE
    boxer init MyProject
    # Creates MyProject in current directory, auto-selects box

    .EXAMPLE
    boxer init MyProject C:\Dev\MyProject
    # Creates project at specific path

    .EXAMPLE
    boxer init -Name MyProject -Box AmiDevBox
    # Explicitly specifies box to use
    #>
    param(
        [Parameter(Position=0)]
        [string]$Name = "",

        [Parameter(Position=1)]
        [string]$Path = "",

        [string]$Box = ""
    )

    # FIRST: Detect if current directory is already a box project
    $CurrentDirIsBox = Test-Path (Join-Path (Get-Location) ".box")
    
    # Determine target directory and update mode
    $IsUpdate = $false
    $TargetDir = ""
    
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        # Path explicitly provided - resolve and check
        $TargetDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $BoxPath = Join-Path $TargetDir ".box"
        $IsUpdate = (Test-Path $TargetDir) -and (Test-Path $BoxPath)
        
        # Error if directory exists but not a box project
        if ((Test-Path $TargetDir) -and -not $IsUpdate) {
            Write-Err "Directory '$TargetDir' exists but is not a Box project"
            Write-Host "  Remove the directory or choose a different path" -ForegroundColor Yellow
            return
        }
    } elseif ($CurrentDirIsBox) {
        # No path provided but current dir is a box → update current directory
        $TargetDir = (Get-Location).Path
        $IsUpdate = $true
    }

    # In update mode, extract name from existing directory
    if ($IsUpdate) {
        $SafeName = Split-Path -Leaf $TargetDir
    } else {
        # Creation mode - prompt for name if not provided
        if ([string]::IsNullOrWhiteSpace($Name)) {
            $Name = Read-Host "Project name"
            if ([string]::IsNullOrWhiteSpace($Name)) {
                Write-Err "Project name is required"
                return
            }
        }

        # Sanitize project name
        $SafeName = Sanitize-ProjectName -Name $Name
        if ([string]::IsNullOrWhiteSpace($SafeName)) {
            Write-Err "Invalid project name after sanitization"
            return
        }

        # Determine target directory
        if ([string]::IsNullOrWhiteSpace($Path)) {
            $TargetDir = Join-Path (Get-Location) $SafeName
        } else {
            $TargetDir = $Path
        }

        # Resolve to absolute path
        $TargetDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetDir)
    }

    # Update BoxPath for later use
    $BoxPath = Join-Path $TargetDir ".box"

    # Get installed boxes
    $InstalledBoxes = Get-InstalledBoxes

    if ($InstalledBoxes.Count -eq 0) {
        Write-Err "No boxes installed"
        Write-Host ""
        Write-Host "  Install a box first:" -ForegroundColor Yellow
        Write-Host "    irm https://raw.githubusercontent.com/vbuzzano/AmiDevBox/main/boxer.ps1 | iex" -ForegroundColor Cyan
        return
    }

    # Determine which box to use
    $SelectedBox = ""

    if (-not [string]::IsNullOrWhiteSpace($Box)) {
        # Box explicitly specified
        if ($InstalledBoxes -contains $Box) {
            $SelectedBox = $Box
        } else {
            Write-Err "Box '$Box' not found"
            Write-Host ""
            Write-Host "  Available boxes:" -ForegroundColor Yellow
            $InstalledBoxes | ForEach-Object { Write-Host "    - $_" -ForegroundColor Cyan }
            return
        }
    } elseif ($InstalledBoxes.Count -eq 1) {
        # Auto-select if only one box installed
        $SelectedBox = $InstalledBoxes[0]
        Write-Host "  Using box: $SelectedBox" -ForegroundColor Gray
    } else {
        # Multiple boxes - prompt user
        Write-Host ""
        Write-Host "  Select a box:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $InstalledBoxes.Count; $i++) {
            Write-Host "    [$($i+1)] $($InstalledBoxes[$i])" -ForegroundColor Cyan
        }
        Write-Host ""
        $choice = Read-Host "  Choose box (1-$($InstalledBoxes.Count))"

        $choiceNum = 0
        if ([int]::TryParse($choice, [ref]$choiceNum) -and $choiceNum -ge 1 -and $choiceNum -le $InstalledBoxes.Count) {
            $SelectedBox = $InstalledBoxes[$choiceNum - 1]
        } else {
            Write-Err "Invalid choice"
            return
        }
    }

    # Verify box compatibility for updates
    if ($IsUpdate) {
        $BoxMetadataPath = Join-Path $BoxPath "metadata.psd1"
        if (Test-Path $BoxMetadataPath) {
            try {
                $metadata = Import-PowerShellDataFile $BoxMetadataPath
                $CurrentBoxName = $metadata.BoxName
                
                if ($CurrentBoxName -ne $SelectedBox) {
                    Write-Err "Cannot update: existing project uses '$CurrentBoxName', trying to init '$SelectedBox'"
                    Write-Host ""
                    Write-Host "  To change box type, create a new project" -ForegroundColor Yellow
                    return
                }
            } catch {
                Write-Host "  ⚠ Could not read box metadata, proceeding with update..." -ForegroundColor Yellow
            }
        }
    }

    Write-Host ""
    if ($IsUpdate) {
        # UPDATE MODE
        Write-Step "Updating project: $SafeName"
        Write-Host "  Directory: $TargetDir" -ForegroundColor Gray
        Write-Host "  Box: $SelectedBox" -ForegroundColor Gray
        Write-Host ""

        try {
            $BoxingDir = "$env:USERPROFILE\Documents\PowerShell\Boxing"
            $SourceBoxDir = Join-Path (Join-Path $BoxingDir "Boxes") $SelectedBox

            Write-Step "Updating box files..."

            # Update .box/ files
            $filesToCopy = Get-ChildItem -Path $SourceBoxDir -File
            foreach ($file in $filesToCopy) {
                if ($file.Name -eq "boxer.ps1") { continue }
                $destPath = Join-Path $BoxPath $file.Name
                Copy-Item -Path $file.FullName -Destination $destPath -Force
                Write-Success "Updated: $($file.Name)"
            }

            # Update tpl/
            $SourceTplDir = Join-Path $SourceBoxDir "tpl"
            if (Test-Path $SourceTplDir) {
                $DestTplDir = Join-Path $BoxPath "tpl"
                if (Test-Path $DestTplDir) {
                    Remove-Item -Path $DestTplDir -Recurse -Force
                }
                Copy-Item -Path $SourceTplDir -Destination $DestTplDir -Recurse -Force
                $tplCount = (Get-ChildItem -Path $DestTplDir -File -Recurse).Count
                Write-Success "Updated: tpl/ ($tplCount templates)"
            }

            Write-Host ""
            Write-Success "Project updated: $SafeName ($SelectedBox)"
            Write-Host ""

        } catch {
            Write-Host ""
            Write-Host "❌ Project update failed: $_" -ForegroundColor Red
            Write-Host ""
        }

    } else {
        # CREATION MODE
        Write-Step "Creating project: $SafeName"
        Write-Host "  Directory: $TargetDir" -ForegroundColor Gray
        Write-Host "  Box: $SelectedBox" -ForegroundColor Gray
        Write-Host ""

        try {
            # Create project directory
            New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
            Track-Creation $TargetDir 'directory'

            # Create .box directory
            $BoxPath = Join-Path $TargetDir ".box"
            New-Item -ItemType Directory -Path $BoxPath -Force | Out-Null
            Track-Creation $BoxPath 'directory'

            # Copy box files from Boxing\Boxes\{SelectedBox}\ to .box\
            $BoxingDir = "$env:USERPROFILE\Documents\PowerShell\Boxing"
            $SourceBoxDir = Join-Path (Join-Path $BoxingDir "Boxes") $SelectedBox

            Write-Step "Copying box files..."

            # Get all files in source box directory
            $filesToCopy = Get-ChildItem -Path $SourceBoxDir -File

            foreach ($file in $filesToCopy) {
                # Skip boxer.ps1 (global only, not for projects)
                if ($file.Name -eq "boxer.ps1") {
                    continue
                }

                $destPath = Join-Path $BoxPath $file.Name
                Copy-Item -Path $file.FullName -Destination $destPath -Force
                Track-Creation $destPath 'file'
                Write-Success "Copied: $($file.Name)"
            }

            # Copy tpl/ directory recursively if it exists
            $SourceTplDir = Join-Path $SourceBoxDir "tpl"
            if (Test-Path $SourceTplDir) {
                $DestTplDir = Join-Path $BoxPath "tpl"
                Copy-Item -Path $SourceTplDir -Destination $DestTplDir -Recurse -Force
                Track-Creation $DestTplDir 'directory'

                $tplCount = (Get-ChildItem -Path $DestTplDir -File -Recurse).Count
                Write-Success "Copied: tpl/ ($tplCount templates)"
            }

            # Create basic project structure
            Write-Step "Creating project structure..."
            @('src', 'docs', 'scripts', 'vendor') | ForEach-Object {
                $dirPath = Join-Path $TargetDir $_
                New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
                Track-Creation $dirPath 'directory'
            }
            Write-Success "Created: src, docs, scripts, vendor"

            Write-Host ""
            Write-Success "Project created: $SafeName"
            Write-Host ""
            Write-Host "  Next steps:" -ForegroundColor Cyan
            Write-Host "    cd $SafeName" -ForegroundColor White
            Write-Host "    box install" -ForegroundColor White
            Write-Host ""

        } catch {
            Write-Host ""
            Write-Host "❌ Project creation failed: $_" -ForegroundColor Red
            Write-Host ""
            Write-Host "  Possible causes:" -ForegroundColor Yellow
            Write-Host "    - Insufficient disk space" -ForegroundColor White
            Write-Host "    - Permission denied" -ForegroundColor White
            Write-Host "    - Path too long" -ForegroundColor White
            Write-Host ""
            Rollback-Creation
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
                    Write-Success "Installed: boxer.ps1"
                } catch {
                    throw "Failed to download boxer.ps1: $_"
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

            # Create/update init.ps1 alongside boxer.ps1
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
        }

        # Modify PowerShell profile
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
            Write-Success "Profile ready"
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
            Write-Success "Profile configured"
        }

        # Install box if this is a box repository (not Boxing main repo)
        if ($SourceRepo) {
            Install-CurrentBox -BoxName $SourceRepo -BoxingDir $BoxingDir
        }

        # Determine if we need to load functions in current session
        $ProfileNeedsConfig = -not ($ProfileContent -match '#region boxing')
        $FunctionsNeedLoading = $ProfileNeedsConfig -or -not (Get-Command -Name boxer -ErrorAction SilentlyContinue)

        # Load functions in current session only if needed (profile not configured or function missing)
        if ($FunctionsNeedLoading) {
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
        }

        # Display appropriate completion message
        if (-not $BoxerAlreadyInstalled) {
            # First installation
            Write-Success "✓ Boxing functions loaded (boxer, box)"
            Write-Success "Boxing system installed successfully!"
            Write-Host ""
            Write-Host "  Ready to use! Try:" -ForegroundColor Cyan
            Write-Host "    boxer init MyProject" -ForegroundColor White
            Write-Host ""
            Write-Host "  💡 Recommended: Restart PowerShell for permanent installation" -ForegroundColor Yellow
            Write-Host "     (functions work now, but restart ensures they persist)" -ForegroundColor DarkGray
        }
        # Update or already up-to-date: no additional message needed

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

    try {
        $BoxesDir = Join-Path $BoxingDir "Boxes"
        $BoxDir = Join-Path $BoxesDir $BoxName
        $BoxMetadataPath = Join-Path $BoxDir "metadata.psd1"

        # Base URL for downloads
        $BaseUrl = "https://raw.githubusercontent.com/vbuzzano/$BoxName/main"

        # Get installed version and boxer version
        $InstalledVersion = Get-InstalledVersion -MetadataPath $BoxMetadataPath
        $InstalledBoxerVersion = $null
        if (Test-Path $BoxMetadataPath) {
            $metadata = Import-PowerShellDataFile $BoxMetadataPath
            $InstalledBoxerVersion = $metadata.BoxerVersion
        }

        # Get remote version and boxer version from GitHub
        $RemoteVersion = $null
        $RemoteBoxerVersion = $null
        try {
            $RemoteMetadataUrl = "$BaseUrl/metadata.psd1"
            $RemoteMetadataContent = Invoke-RestMethod -Uri $RemoteMetadataUrl -ErrorAction Stop

            # Parse version and boxer version from downloaded content
            if ($RemoteMetadataContent -match 'Version\s*=\s*"([^"]+)"') {
                $RemoteVersion = $Matches[1]
            }
            if ($RemoteMetadataContent -match 'BoxerVersion\s*=\s*"([^"]+)"') {
                $RemoteBoxerVersion = $Matches[1]
            }
        } catch {
            Write-Warn "Could not fetch remote version, proceeding with install"
        }

        # Determine if update is needed
        $NeedsUpdate = $false
        $UpdateReason = ""

        if (-not (Test-Path $BoxDir)) {
            $NeedsUpdate = $true
            $UpdateReason = "Installing $BoxName box..."
        } elseif ($RemoteVersion -and $InstalledVersion -and (Compare-Version -Version1 $RemoteVersion -Version2 $InstalledVersion) -gt 0) {
            $NeedsUpdate = $true
            $UpdateReason = "Updating $BoxName box ($InstalledVersion → $RemoteVersion)..."
        } elseif ($RemoteVersion -and $InstalledVersion -and (Compare-Version -Version1 $RemoteVersion -Version2 $InstalledVersion) -eq 0) {
            Write-Host ""
            Write-Host "=== $BoxName Box ===" -ForegroundColor Cyan
            Write-Success "$BoxName already up-to-date (v$InstalledVersion)"
            return
        } else {
            Write-Host ""
            Write-Host "=== $BoxName Box ===" -ForegroundColor Cyan
            Write-Success "$BoxName already installed (v$InstalledVersion)"
            return
        }

        if ($NeedsUpdate) {
            Write-Step $UpdateReason
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
            $action = if ($InstalledVersion) { "Updated" } else { "Installed" }
            Write-Success "${action}: box.ps1"
        } catch {
            throw "Failed to download box.ps1: $_"
        }

        # Download config.psd1
        Write-Step "Downloading config.psd1..."
        try {
            Invoke-RestMethod -Uri "$BaseUrl/config.psd1" -OutFile (Join-Path $BoxDir "config.psd1")
            $action = if ($InstalledVersion) { "Updated" } else { "Installed" }
            Write-Success "${action}: config.psd1"
        } catch {
            Write-Warn "config.psd1 not found (optional)"
        }

        # Download metadata.psd1
        Write-Step "Downloading metadata.psd1..."
        try {
            Invoke-RestMethod -Uri "$BaseUrl/metadata.psd1" -OutFile (Join-Path $BoxDir "metadata.psd1")
            $action = if ($InstalledVersion) { "Updated" } else { "Installed" }
            Write-Success "${action}: metadata.psd1"
        } catch {
            Write-Warn "metadata.psd1 not found (optional)"
        }

        # Download env.ps1 (environment configuration)
        Write-Step "Downloading env.ps1..."
        try {
            Invoke-RestMethod -Uri "$BaseUrl/env.ps1" -OutFile (Join-Path $BoxDir "env.ps1")
            $action = if ($InstalledVersion) { "Updated" } else { "Installed" }
            Write-Success "${action}: env.ps1"
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
                    $action = if ($InstalledVersion) { "Updated" } else { "Installed" }
                    Write-Success "${action}: tpl/$($File.name)"
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

