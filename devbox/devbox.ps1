param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$scriptDir = Split-Path -Parent $PSCommandPath
$boxerPath = Join-Path $scriptDir 'boxer.ps1'
$boxingPath = Join-Path $scriptDir 'boxing.ps1'

if (Test-Path $boxerPath) {
    . $boxerPath
    Initialize-Boxing -Arguments $Arguments
    return
}

if (Test-Path $boxingPath) {
    . $boxingPath
    Initialize-Boxing -Arguments $Arguments
    return
}

Write-Warning "Unable to locate boxer.ps1 or boxing.ps1 next to devbox.ps1."
