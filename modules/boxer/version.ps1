# Boxer Version Command
# Display version information for boxer and installed boxes

function Invoke-Boxer-Version {
    # Detect version (prefer embedded variable, fallback to file parsing)
    $BoxerVersion = if ($script:BoxerVersion) {
        $script:BoxerVersion
    } else {
        "Unknown"
    }

    Write-Host "Boxing v$BoxerVersion" -ForegroundColor Cyan
}
