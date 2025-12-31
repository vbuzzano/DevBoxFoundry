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
        Write-Info "Next steps:"
        Write-Info "  cd $SafeName"
        Write-Info "  box install"

    } catch {
        Write-Err "Project creation failed: $_"
        if (Test-Path $TargetDir) {
            Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
