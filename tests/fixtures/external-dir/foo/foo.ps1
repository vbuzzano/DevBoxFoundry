param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputArgs
)

if ($InputArgs.Count -gt 0) {
    "foo-default:" + ($InputArgs -join '|')
}
else {
    "foo-default"
}
