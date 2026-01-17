param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputArgs
)

"foo-bar:" + ($InputArgs -join '|')
