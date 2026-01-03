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
        $BoxDir = Join-Path $BoxingDir $BoxName

        # Check if box already installed
        if (Test-Path $BoxDir) {
            Write-Error-Custom "Box '$BoxName' is already installed at $BoxDir"
            return
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

        # Copy box.ps1 from dist
        $BoxSource = Join-Path $PSScriptRoot "../../dist/box.ps1"
        if (Test-Path $BoxSource) {
            $BoxDest = Join-Path $BoxDir "box.ps1"
            Copy-Item -Force $BoxSource $BoxDest
            Write-Success "Copied: box.ps1"
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
        Write-Error-Custom "Box installation failed: $_"
        
        # Cleanup on error
        if (Test-Path $BoxDir) {
            Remove-Item -Path $BoxDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}
