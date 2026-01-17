# Box Version Command
# Display box runtime version (simple output like boxer version)

function Invoke-Box-Version {
<#
.SYNOPSIS
    Display box runtime version
#>
    $BoxVersion = if ($script:BoxerVersion) {
        $script:BoxerVersion
    } else {
        "Unknown"
    }

    Write-Host "Box v$BoxVersion" -ForegroundColor Cyan
}
