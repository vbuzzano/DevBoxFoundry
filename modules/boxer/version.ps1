# Boxer Version Command
# Display version information for boxer and installed boxes

function Invoke-Boxer-Version {
<#
.SYNOPSIS
    Display boxer version information
#>
    $BoxerVersion = if ($script:BoxerVersion) {
        $script:BoxerVersion
    } else {
        "Unknown"
    }

    Write-Host "Boxer v$BoxerVersion" -ForegroundColor Cyan
}
