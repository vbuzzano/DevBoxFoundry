param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputArgs
)

"handler:" + ($InputArgs -join '|')
