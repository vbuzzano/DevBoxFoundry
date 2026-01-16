function Invoke-MetadataSampleDispatcher {
    param(
        [string[]]$CommandPath,
        [string[]]$Arguments
    )

    "dispatch:" + ($CommandPath -join '>') + '|' + ($Arguments -join '>')
}

function Invoke-MetadataSampleLoad {
    "metadata-sample-load"
}
