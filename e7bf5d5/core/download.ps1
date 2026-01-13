# ============================================================================
# Download Functions
# ============================================================================

function Invoke-WithRetry {
    <#
    .SYNOPSIS
    Executes a script block with retry logic and exponential backoff.

    .DESCRIPTION
    Retries a script block up to a specified number of times with exponential backoff
    between attempts. Useful for network operations that may fail temporarily.

    .PARAMETER ScriptBlock
    The script block to execute

    .PARAMETER MaxAttempts
    Maximum number of retry attempts (default: 3)

    .PARAMETER InitialDelaySeconds
    Initial delay in seconds before first retry (default: 1)

    .EXAMPLE
    Invoke-WithRetry -ScriptBlock { Invoke-WebRequest -Uri $url } -MaxAttempts 3
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

            Write-Info "Attempt $attempt failed. Retrying in $delay seconds..."
            Start-Sleep -Seconds $delay

            # Exponential backoff: 1s, 2s, 4s, 8s...
            $delay = $delay * 2
            $attempt++
        }
    }
}

function Test-FileHash {
    <#
    .SYNOPSIS
    Verifies the SHA256 hash of a downloaded file.

    .DESCRIPTION
    Computes the SHA256 hash of a file and compares it to the expected hash value.
    Returns $true if hashes match, $false otherwise.

    .PARAMETER FilePath
    Path to the file to verify

    .PARAMETER ExpectedHash
    Expected SHA256 hash value (case-insensitive)

    .OUTPUTS
    Returns $true if hash matches, $false if mismatch or error

    .EXAMPLE
    if (Test-FileHash -FilePath $file -ExpectedHash $hash) { ... }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string]$ExpectedHash
    )

    if (-not (Test-Path $FilePath)) {
        Write-Err "File not found: $FilePath"
        return $false
    }

    try {
        $actualHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash

        if ($actualHash -eq $ExpectedHash) {
            Write-Info "Hash verified: OK"
            return $true
        }
        else {
            Write-Err "Hash mismatch!"
            Write-Err "Expected: $ExpectedHash"
            Write-Err "Actual:   $actualHash"
            return $false
        }
    }
    catch {
        Write-Err "Hash verification failed: $_"
        return $false
    }
}

function Download-File {
    <#
    .SYNOPSIS
    Downloads a file from a URL with support for different source types.

    .DESCRIPTION
    Downloads a file with automatic retry logic and special handling for SourceForge redirects.
    Supports HTTP, HTTPS, and SourceForge download links.

    .PARAMETER Url
    The URL to download from

    .PARAMETER FileName
    The filename to save as in the cache directory

    .PARAMETER SourceType
    The type of source: 'http' (default), 'sourceforge'

    .OUTPUTS
    Returns the path to the downloaded file, or $null on failure

    .EXAMPLE
    Download-File -Url $url -FileName "tool.zip" -SourceType "sourceforge"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$true)]
        [string]$FileName,

        [ValidateSet('http', 'sourceforge')]
        [string]$SourceType = 'http'
    )

    # Ensure cache directory exists
    if (-not (Test-Path $CacheDir)) {
        New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
    }

    $outPath = Join-Path $CacheDir $FileName

    if (Test-Path $outPath) {
        Write-Info "Already downloaded: $FileName"
        return $outPath
    }

    Write-Info "Downloading $FileName..."

    # T020/T037: Progress reporting for SourceForge
    if ($SourceType -eq 'sourceforge') {
        Write-Info "[1/2] Following SourceForge redirects..."
    }

    # T019: Integrate Invoke-WithRetry for downloads
    try {
        $downloadResult = Invoke-WithRetry -ScriptBlock {
            $ProgressPreference = 'SilentlyContinue'

            # T018: SourceForge redirect handling - needs two-step process
            if ($SourceType -eq 'sourceforge') {
                # Step 1: Get the download page to extract real download URL
                Write-Info "[1/2] Fetching SourceForge download page..."
                $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 5 -AllowInsecureRedirect

                # Extract the real download URL from meta refresh or download link
                $realUrl = $null
                if ($response.Content -match 'url=([^"]+lha[^"]+\.zip[^"]*)"') {
                    $realUrl = $Matches[1]
                }
                elseif ($response.Content -match 'href="(https://downloads\.sourceforge\.net[^"]+)"') {
                    $realUrl = $Matches[1]
                }

                if ($realUrl) {
                    # Decode HTML entities
                    $realUrl = $realUrl -replace '&amp;', '&'
                    Write-Info "[2/2] Downloading binary from: $($realUrl.Substring(0, [Math]::Min(80, $realUrl.Length)))..."

                    # Step 2: Download from real URL
                    Invoke-WebRequest -Uri $realUrl -OutFile $outPath -UseBasicParsing -MaximumRedirection 5 -AllowInsecureRedirect
                }
                else {
                    throw "Could not extract download URL from SourceForge page"
                }
            }
            else {
                # Standard HTTP download
                $webParams = @{
                    Uri = $Url
                    OutFile = $outPath
                    UseBasicParsing = $true
                }

                Invoke-WebRequest @webParams
            }

            $ProgressPreference = 'Continue'
        } -MaxAttempts 3 -InitialDelaySeconds 1

        $size = [math]::Round((Get-Item $outPath).Length / 1KB, 1)
        Write-Success "Downloaded: $size KB"
        return $outPath
    }
    catch {
        # T021: SourceForge-specific error messages
        if ($SourceType -eq 'sourceforge') {
            Write-Err "SourceForge download failed: $_"
            Write-Err "Tip: Verify the URL is correct. SourceForge links may change."
            Write-Err "Visit the project page to get the latest download link."
        }
        else {
            Write-Err "Download failed: $_"
        }

        # Clean up partial download
        if (Test-Path $outPath) {
            Remove-Item $outPath -Force -ErrorAction SilentlyContinue
        }

        return $null
    }
}
