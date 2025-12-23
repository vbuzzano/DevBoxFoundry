<#
.SYNOPSIS
    DevBox Bootstrap Installer

.DESCRIPTION
    Creates or initializes a DevBox project structure for cross-platform development.
    Supports two modes: init (new project) and add (existing project).

    Usage:
      devbox init MyProject [Description]
      devbox add [in existing directory]

    Remote installation:
      irm https://github.com/vbuzzano/DevBoxFoundry/raw/main/devbox.ps1 | iex -ArgumentList 'init', 'MyProject'

.PARAMETER Mode
    Operation mode: 'init' or 'add'. Auto-detected if not specified.

.PARAMETER ProjectName
    Project name (required for init mode). Can contain spaces - will be sanitized.

.PARAMETER Description
    Project description (optional). Used in config and README generation.

.PARAMETER UseVSCode
    Auto-answer for VS Code integration (for scripting). Prompts if not specified.

.EXAMPLE
    devbox init MyProject "My awesome project"
    devbox add
    irm https://.../devbox.ps1 | iex

.NOTES
    Author: ReddoC
    Version: 0.1.0
    Requires: PowerShell 7+, Git
#>

param(
    [Parameter(Position=0)]
    [ValidateSet('init', 'add')]
    [string]$Mode,

    [Parameter(Position=1)]
    [string]$ProjectName,

    [Parameter(Position=2)]
    [string]$Description,

    [Parameter()]
    [switch]$UseVSCode
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:Config = @{
    Version = '0.1.0'
    RepositoryUrl = 'https://github.com/vbuzzano/DevBoxFoundry.git'
    BoxDir = '.box'
    ConfigFile = 'box.config.psd1'
    EnvFile = '.env'
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Write-Title {
    param([string]$Text)
    Write-Host "`n" -NoNewline
    Write-Host '━' * 60 -ForegroundColor DarkMagenta
    Write-Host "  $Text" -ForegroundColor White
    Write-Host '━' * 60 -ForegroundColor DarkMagenta
}

function Write-Step {
    param([string]$Text)
    Write-Host "  ⏳ $Text" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host "  ✓ $Text" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Text)
    Write-Host "  ❌ $Text" -ForegroundColor Red
}

function Test-Prerequisites {
    # Check if git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error-Custom 'git is not installed'
        Write-Host ''
        Write-Host '  Download from: https://git-scm.com/download/win' -ForegroundColor Yellow
        exit 1
    }
    Write-Success 'git is installed'
}

function Sanitize-ProjectName {
    param([string]$Name)
    # Remove/replace invalid characters for directory names
    $sanitized = $Name -replace '[/\\()^''":\[\]<>|?*]', '-'
    # Remove trailing dots and spaces
    $sanitized = $sanitized -replace '[\s.]+$', ''
    # Remove leading/trailing dashes
    $sanitized = $sanitized -replace '^-+|-+$', ''
    return $sanitized
}

# ============================================================================
# PHASE 1: INIT MODE
# ============================================================================

function Initialize-NewProject {
    param(
        [string]$ProjectName,
        [string]$Description,
        [switch]$VSCode
    )

    # Sanitize project name
    $SafeName = Sanitize-ProjectName -Name $ProjectName
    if (-not $SafeName) {
        Write-Error-Custom 'Invalid project name after sanitization'
        exit 1
    }

    $TargetDir = Join-Path (Get-Location) $SafeName

    # Check if directory exists
    if (Test-Path $TargetDir) {
        Write-Error-Custom "Directory '$SafeName' already exists"
        exit 1
    }

    Write-Title "Creating Project: $ProjectName"
    Write-Host "Directory: $SafeName" -ForegroundColor Gray
    Write-Host ''

    # Create project directory
    Write-Step 'Creating project directory'
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Write-Success "Created: $SafeName"

    # Clone DevBox repository
    Write-Step 'Cloning DevBox repository'
    Push-Location $TargetDir
    try {
        git clone $Script:Config.RepositoryUrl $Script:Config.BoxDir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to clone repository'
        }
        Write-Success 'Repository cloned to .box'
    }
    catch {
        Write-Error-Custom "Clone failed: $_"
        Pop-Location
        exit 1
    }
    finally {
        Pop-Location
    }

    # Generate box.config.psd1
    Write-Step 'Generating configuration file'
    $ConfigPath = Join-Path $TargetDir $Script:Config.ConfigFile
    $TemplateConfig = @"
@{
    Name = '$ProjectName'
    Description = '$Description'
    ProgramName = '$SafeName'
    Version = '0.1.0'
    DefaultCPU = 'm68020'
    DefaultFPU = ''
}
"@
    Set-Content -Path $ConfigPath -Value $TemplateConfig -Encoding UTF8
    Write-Success "Generated: box.config.psd1"

    # Create .env file
    Write-Step 'Creating environment file'
    $EnvPath = Join-Path $TargetDir $Script:Config.EnvFile
    $EnvContent = @"
# DevBox environment - $ProjectName
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Project
PROJECT_NAME=$ProjectName
PROGRAM_NAME=$SafeName
VERSION=0.1.0

# Amiga Development
DefaultCPU=m68020
DefaultFPU=
"@
    Set-Content -Path $EnvPath -Value $EnvContent -Encoding UTF8
    Write-Success 'Created: .env'

    # Create directories
    Write-Step 'Creating project structure'
    foreach ($Dir in @('src', 'include', 'lib', 'bin')) {
        $DirPath = Join-Path $TargetDir $Dir
        New-Item -ItemType Directory -Path $DirPath -Force | Out-Null
    }
    Write-Success 'Created: src/, include/, lib/, bin/'

    # Create README.md
    Write-Step 'Generating README'
    $ReadmePath = Join-Path $TargetDir 'README.md'
    $ReadmeContent = @"
# $ProjectName

$Description

## Project Structure

- **src/**: Source code
- **include/**: Header files
- **lib/**: Libraries
- **bin/**: Compiled binaries
- **.box/**: DevBox development tools

## Getting Started

1. Review configuration: \`box.config.psd1\`
2. Load environment: \`. .\.env.ps1\` (in PowerShell)
3. Build: \`box build\` (or \`make\` if configured)

## Documentation

See **.box/** directory for build system documentation.
"@
    Set-Content -Path $ReadmePath -Value $ReadmeContent -Encoding UTF8
    Write-Success 'Generated: README.md'

    # VS Code integration (optional)
    if ($VSCode) {
        Write-Step 'Configuring VS Code'
        $VSCodeDir = Join-Path $TargetDir '.vscode'
        New-Item -ItemType Directory -Path $VSCodeDir -Force | Out-Null
        
        $SettingsPath = Join-Path $VSCodeDir 'settings.json'
        $SettingsContent = @"
{
  "terminal.integrated.env.windows": {
    "DEVBOX_ENV": ".env.ps1"
  },
  "powershell.codeFormatting.preset": "OTBS",
  "[powershell]": {
    "editor.defaultFormatter": "ms-vscode.powershell",
    "editor.formatOnSave": true
  }
}
"@
        Set-Content -Path $SettingsPath -Value $SettingsContent -Encoding UTF8
        Write-Success 'Created: .vscode/settings.json'
    }

    # Copy box.ps1 to project root
    Write-Step 'Setting up box.ps1'
    $SourceBox = Join-Path $TargetDir $Script:Config.BoxDir 'box.ps1'
    $TargetBox = Join-Path $TargetDir 'box.ps1'
    if (Test-Path $SourceBox) {
        Copy-Item $SourceBox $TargetBox -Force
        Write-Success 'Copied: box.ps1 to root'
    }

    Write-Host ''
    Write-Host '✅ Project created successfully!' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Next steps:' -ForegroundColor Yellow
    Write-Host "  1. cd $SafeName" -ForegroundColor White
    Write-Host '  2. Review box.config.psd1' -ForegroundColor White
    Write-Host '  3. Run: ./box.ps1 help' -ForegroundColor White
    Write-Host ''
    Write-Host "📁 Project directory: $(Join-Path (Get-Location) $SafeName)" -ForegroundColor Cyan
    Write-Host ''
}

# ============================================================================
# PHASE 2: ADD MODE
# ============================================================================

function Add-ToExistingProject {
    Write-Title 'Adding DevBox to Existing Project'

    $CurrentDir = Get-Location
    Write-Host "Directory: $CurrentDir" -ForegroundColor Gray
    Write-Host ''

    $BoxDir = Join-Path $CurrentDir $Script:Config.BoxDir

    # Check if .box already exists
    if (Test-Path $BoxDir) {
        Write-Host '  ℹ️ .box/ directory already exists, skipping clone' -ForegroundColor Cyan
    }
    else {
        Write-Step 'Cloning DevBox repository'
        try {
            git clone $Script:Config.RepositoryUrl $Script:Config.BoxDir 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw 'Failed to clone repository'
            }
            Write-Success 'Repository cloned to .box'
        }
        catch {
            Write-Error-Custom "Clone failed: $_"
            exit 1
        }
    }

    # Create/update config
    $ConfigPath = Join-Path $CurrentDir $Script:Config.ConfigFile
    if (-not (Test-Path $ConfigPath)) {
        Write-Step 'Generating configuration file'
        $ProjectName = Split-Path $CurrentDir -Leaf
        $ConfigContent = @"
@{
    Name = '$ProjectName'
    Description = ''
    ProgramName = '$ProjectName'
    Version = '0.1.0'
    DefaultCPU = 'm68020'
    DefaultFPU = ''
}
"@
        Set-Content -Path $ConfigPath -Value $ConfigContent -Encoding UTF8
        Write-Success 'Generated: box.config.psd1'
    }
    else {
        Write-Host '  ℹ️ box.config.psd1 already exists, skipping' -ForegroundColor Cyan
    }

    # Create/backup .env
    $EnvPath = Join-Path $CurrentDir $Script:Config.EnvFile
    if (-not (Test-Path $EnvPath)) {
        Write-Step 'Creating environment file'
        $EnvContent = @"
# DevBox environment
# Add your custom environment variables here

DefaultCPU=m68020
DefaultFPU=
"@
        Set-Content -Path $EnvPath -Value $EnvContent -Encoding UTF8
        Write-Success 'Created: .env'
    }
    else {
        Write-Step 'Backing up existing .env'
        $BackupPath = "$EnvPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $EnvPath $BackupPath
        Write-Success "Backup: $([System.IO.Path]::GetFileName($BackupPath))"
    }

    # Backup existing critical files if they exist
    foreach ($File in @('README.md', 'Makefile', 'box.config.psd1')) {
        $FilePath = Join-Path $CurrentDir $File
        if (Test-Path $FilePath) {
            $BackupPath = "$FilePath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $FilePath $BackupPath -Force
            Write-Host "  💾 Backed up: $File → $(Split-Path $BackupPath -Leaf)" -ForegroundColor Gray
        }
    }

    # Copy box.ps1 to root
    Write-Step 'Setting up box.ps1'
    $SourceBox = Join-Path $BoxDir 'box.ps1'
    $TargetBox = Join-Path $CurrentDir 'box.ps1'
    if (Test-Path $SourceBox) {
        Copy-Item $SourceBox $TargetBox -Force
        Write-Success 'Copied: box.ps1 to root'
    }
    else {
        Write-Host "  ⚠️ box.ps1 not found in .box/" -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '✅ DevBox added successfully!' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Next steps:' -ForegroundColor Yellow
    Write-Host '  1. Review box.config.psd1' -ForegroundColor White
    Write-Host '  2. Update .env if needed' -ForegroundColor White
    Write-Host '  3. Run: ./box.ps1 help' -ForegroundColor White
    Write-Host ''
}

# ============================================================================
# MAIN
# ============================================================================

function Main {
    Write-Host ''
    Write-Host '🧙 DevBox Bootstrap v0.1.0' -ForegroundColor Cyan
    Write-Host ''

    # Check prerequisites
    Test-Prerequisites

    # Detect mode if not specified
    if (-not $Mode) {
        if ($ProjectName) {
            $Mode = 'init'
        }
        elseif (Test-Path '.box') {
            $Mode = 'add'
        }
        else {
            # Interactive mode
            Write-Host 'What would you like to do?' -ForegroundColor Yellow
            Write-Host "  [i] init - Create new project" -ForegroundColor White
            Write-Host "  [a] add  - Add DevBox to existing project" -ForegroundColor White
            $Choice = Read-Host 'Select'
            
            if ($Choice -eq 'i') {
                $Mode = 'init'
            }
            elseif ($Choice -eq 'a') {
                $Mode = 'add'
            }
            else {
                Write-Error-Custom 'Invalid choice'
                exit 1
            }
        }
    }

    # Execute mode
    switch ($Mode) {
        'init' {
            if (-not $ProjectName) {
                $ProjectName = Read-Host 'Project name'
                if (-not $ProjectName) {
                    Write-Error-Custom 'Project name is required'
                    exit 1
                }
            }
            
            if (-not $Description) {
                $Description = Read-Host 'Description (optional)'
            }

            $UseVSCodeChoice = $UseVSCode
            if (-not $PSBoundParameters.ContainsKey('UseVSCode')) {
                Write-Host ''
                $VSCodeAnswer = Read-Host 'Configure VS Code integration? [y/n]'
                $UseVSCodeChoice = $VSCodeAnswer -eq 'y' -or $VSCodeAnswer -eq 'yes'
            }

            Initialize-NewProject -ProjectName $ProjectName -Description $Description -VSCode:$UseVSCodeChoice
        }
        'add' {
            Add-ToExistingProject
        }
    }

    Write-Host ''
}

# Run main
Main
