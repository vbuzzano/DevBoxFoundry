# ============================================================================
# Boxer Init Module
# ============================================================================
#
# Handles boxer init command - creating new Box projects

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
        $BoxerAlreadyInstalled = Test-Path $BoxerPath
        
        # Always set source repo for AmiDevBox release (hardcoded in dist build)
        $SourceRepo = "AmiDevBox"

        if ($BoxerAlreadyInstalled) {
            Write-Success "boxer.ps1 already installed (skipping copy)"
        } else {
            Write-Step "Installing boxer.ps1..."

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
            Write-Success "Profile already configured (skipping)"
        } else {
            # Add Boxing region to profile
            $BoxingRegion = @"

#region boxing
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
#endregion boxing
"@

            # Append to profile
            $ProfileContent += $BoxingRegion
            Set-Content -Path $ProfilePath -Value $ProfileContent -Encoding UTF8
            Write-Success "Profile configured with boxer and box functions"
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

        Write-Success "Boxing system installed successfully!"
        Write-Host ""
        Write-Host "  To use boxing in this session, run:" -ForegroundColor Cyan
        Write-Host "    . `$env:USERPROFILE\Documents\PowerShell\Boxing\init.ps1" -ForegroundColor White
        Write-Host ""
        Write-Host "  Or restart PowerShell, then run:" -ForegroundColor Cyan
        Write-Host "    boxer init MyProject" -ForegroundColor White

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

        # Check if box already installed
        if (Test-Path $BoxDir) {
            Write-Success "$BoxName already installed (skipping)"
            return
        }

        # Create box directory
        New-Item -ItemType Directory -Path $BoxDir -Force | Out-Null

        # Base URL for downloads
        $BaseUrl = "https://raw.githubusercontent.com/vbuzzano/$BoxName/main"

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

        # Download tpl/ directory
        Write-Step "Downloading templates..."
        $TplDir = Join-Path $BoxDir "tpl"
        New-Item -ItemType Directory -Path $TplDir -Force | Out-Null

        # Use GitHub API to list tpl/ contents
        try {
            $ApiUrl = "https://api.github.com/repos/vbuzzano/$BoxName/contents/tpl"
            $TplFiles = Invoke-RestMethod -Uri $ApiUrl

            foreach ($File in $TplFiles) {
                if ($File.type -eq 'file') {
                    $FilePath = Join-Path $TplDir $File.name
                    Invoke-RestMethod -Uri $File.download_url -OutFile $FilePath
                    Write-Success "Downloaded: tpl/$($File.name)"
                } elseif ($File.type -eq 'dir') {
                    # Recursive download for subdirectories
                    $SubDir = Join-Path $TplDir $File.name
                    New-Item -ItemType Directory -Path $SubDir -Force | Out-Null
                    
                    $SubFiles = Invoke-RestMethod -Uri $File.url
                    foreach ($SubFile in $SubFiles) {
                        if ($SubFile.type -eq 'file') {
                            $SubFilePath = Join-Path $SubDir $SubFile.name
                            Invoke-RestMethod -Uri $SubFile.download_url -OutFile $SubFilePath
                            Write-Success "Downloaded: tpl/$($File.name)/$($SubFile.name)"
                        }
                    }
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

