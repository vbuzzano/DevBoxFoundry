# Load core extract library if not embedded (embedded builds already have it)
if (-not $script:IsEmbedded) {
    $extractCore = Join-Path $PSScriptRoot '..\..\..\core\extract.ps1'
    if (Test-Path $extractCore) {
        . $extractCore
    }
    else {
        throw "Missing core extract library at $extractCore"
    }
}
