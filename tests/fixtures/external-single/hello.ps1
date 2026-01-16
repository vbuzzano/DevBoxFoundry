param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputArgs
)

"hello:" + ($InputArgs -join '|')
