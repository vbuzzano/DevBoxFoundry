# ============================================================================
# Test SourceForge Download
# ============================================================================
# Standalone test script to verify SourceForge download functionality
# Uses the same code as devbox/inc/download.ps1
# ============================================================================

param(
    [string]$TestUrl = "https://gnuwin32.sourceforge.net/downlinks/lha-bin-zip.php",
    [string]$OutputFile = "lha-test-download.zip"
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# Helper Functions (same as devbox)
# ============================================================================

function Write-TestInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-TestErr {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-TestSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Invoke-WithRetry {
    <#
    .SYNOPSIS
    Executes a script block with retry logic and exponential backoff.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [int]$MaxAttempts = 3,

        [int]$InitialDelaySeconds = 1
    )

    $attempt = 1
    $delay = $InitialDelaySeconds

    while ($attempt -le $MaxAttempts) {
        try {
            return & $ScriptBlock
        }
        catch {
            if ($attempt -eq $MaxAttempts) {
                throw
            }

            Write-TestInfo "Attempt $attempt failed. Retrying in $delay seconds..."
            Start-Sleep -Seconds $delay

            # Exponential backoff: 1s, 2s, 4s, 8s...
            $delay = $delay * 2
            $attempt++
        }
    }
}

function Download-FileWithSourceForge {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$true)]
        [string]$OutFile,

        [ValidateSet('http', 'sourceforge')]
        [string]$SourceType = 'sourceforge'
    )

    Write-TestInfo "Starting download test..."
    Write-TestInfo "URL: $Url"
    Write-TestInfo "Output: $OutFile"
    Write-TestInfo "SourceType: $SourceType"
    Write-Host ""

    if ($SourceType -eq 'sourceforge') {
        Write-TestInfo "Following SourceForge redirects..."
    }

    try {
        $downloadResult = Invoke-WithRetry -ScriptBlock {
            $ProgressPreference = 'SilentlyContinue'

            # SourceForge redirect handling - two-step process
            if ($SourceType -eq 'sourceforge') {
                # Step 1: Get the download page to extract real download URL
                Write-TestInfo "Fetching SourceForge download page..."
                $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 5 -AllowInsecureRedirect

                Write-TestInfo "Response content length: $($response.Content.Length) bytes"

                # Extract the real download URL from meta refresh or download link
                $realUrl = $null
                if ($response.Content -match 'url=([^"]+lha[^"]+\.zip[^"]*)"') {
                    $realUrl = $Matches[1]
                    Write-TestInfo "Found URL via meta refresh pattern"
                }
                elseif ($response.Content -match 'href="(https://downloads\.sourceforge\.net[^"]+)"') {
                    $realUrl = $Matches[1]
                    Write-TestInfo "Found URL via href pattern"
                }

                if ($realUrl) {
                    # Decode HTML entities
                    $realUrl = $realUrl -replace '&amp;', '&'
                    Write-TestInfo "Real download URL: $realUrl"

                    # Step 2: Download from real URL
                    Write-TestInfo "Downloading from real URL..."
                    Invoke-WebRequest -Uri $realUrl -OutFile $OutFile -UseBasicParsing -MaximumRedirection 5 -AllowInsecureRedirect
                }
                else {
                    throw "Could not extract download URL from SourceForge page"
                }
            }
            else {
                # Standard HTTP download
                Write-TestInfo "Invoking web request with parameters:"
                $webParams = @{
                    Uri = $Url
                    OutFile = $OutFile
                    UseBasicParsing = $true
                }
                $webParams.GetEnumerator() | ForEach-Object {
                    Write-TestInfo "  $($_.Key): $($_.Value)"
                }
                Invoke-WebRequest @webParams
            }

            $ProgressPreference = 'Continue'
        } -MaxAttempts 3 -InitialDelaySeconds 1

        if (Test-Path $OutFile) {
            $size = [math]::Round((Get-Item $OutFile).Length / 1KB, 1)
            Write-TestSuccess "Downloaded successfully: $size KB"

            # Show file details
            $fileInfo = Get-Item $OutFile
            Write-Host ""
            Write-TestInfo "File details:"
            Write-TestInfo "  Path: $($fileInfo.FullName)"
            Write-TestInfo "  Size: $($fileInfo.Length) bytes ($size KB)"
            Write-TestInfo "  Created: $($fileInfo.CreationTime)"

            return $true
        }
        else {
            Write-TestErr "File was not created"
            return $false
        }
    }
    catch {
        if ($SourceType -eq 'sourceforge') {
            Write-TestErr "SourceForge download failed: $_"
            Write-TestErr "Tip: Verify the URL is correct. SourceForge links may change."
            Write-TestErr "Visit the project page to get the latest download link."
        }
        else {
            Write-TestErr "Download failed: $_"
        }

        # Show exception details
        Write-Host ""
        Write-TestErr "Exception details:"
        Write-TestErr "  Message: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            Write-TestErr "  Inner: $($_.Exception.InnerException.Message)"
        }

        # Clean up partial download
        if (Test-Path $OutFile) {
            Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
            Write-TestInfo "Cleaned up partial download"
        }

        return $false
    }
}

# ============================================================================
# Main Test
# ============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host " SourceForge Download Test" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

# Ensure we're in a temp directory
$testDir = Join-Path $PSScriptRoot "temp-downloads"
if (-not (Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
}

$testFile = Join-Path $testDir $OutputFile

Write-TestInfo "Test directory: $testDir"
Write-Host ""

# Run the test
$result = Download-FileWithSourceForge -Url $TestUrl -OutFile $testFile -SourceType 'sourceforge'

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow

if ($result) {
    Write-TestSuccess "TEST PASSED - Download successful!"
    Write-Host ""
    Write-TestInfo "You can find the downloaded file at:"
    Write-TestInfo "  $testFile"
    Write-Host ""
    Write-TestInfo "To clean up, delete: $testDir"
} else {
    Write-TestErr "TEST FAILED - Download unsuccessful"
    exit 1
}

Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
