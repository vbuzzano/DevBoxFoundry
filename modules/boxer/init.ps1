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
        $ScriptsDir = "$env:USERPROFILE\Documents\PowerShell\Scripts"
        $BoxingDir = "$env:USERPROFILE\Documents\PowerShell\Boxing"
        $ProfilePath = $PROFILE.CurrentUserAllHosts

        # Create Scripts directory
        if (-not (Test-Path $ScriptsDir)) {
            Write-Step "Creating Scripts directory..."
            New-Item -ItemType Directory -Path $ScriptsDir -Force | Out-Null
            Write-Success "Created: $ScriptsDir"
        }

        # Create Boxing directory
        if (-not (Test-Path $BoxingDir)) {
            Write-Step "Creating Boxing directory..."
            New-Item -ItemType Directory -Path $BoxingDir -Force | Out-Null
            Write-Success "Created: $BoxingDir"
        }

        # Note: boxer.ps1 and box.ps1 should already be in Scripts\ (downloaded by install.ps1)
        # Verify they exist
        $BoxerPath = Join-Path $ScriptsDir "boxer.ps1"
        $BoxPath = Join-Path $ScriptsDir "box.ps1"
        
        if (-not (Test-Path $BoxerPath)) {
            throw "boxer.ps1 not found at $BoxerPath. Installation incomplete."
        }
        if (-not (Test-Path $BoxPath)) {
            throw "box.ps1 not found at $BoxPath. Installation incomplete."
        }
        
        Write-Success "Verified: boxer.ps1 and box.ps1 present"

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
    `$boxerPath = "`$env:USERPROFILE\Documents\PowerShell\Scripts\boxer.ps1"
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

        Write-Success "Boxing system installed successfully!"
        Write-Host ""
        Write-Host "  Next steps:" -ForegroundColor Cyan
        Write-Host "    1. Restart PowerShell" -ForegroundColor White
        Write-Host "    2. Run: boxer init MyProject" -ForegroundColor White

    } catch {
        Write-Error-Custom "Installation failed: $_"
        throw
    }
}

