# ============================================================================
# AmiDevBox Template Hooks
# ============================================================================
#
# Custom template replacement syntaxes for Amiga C development

function Hook-BeforeTemplateReplace {
    <#
    .SYNOPSIS
        AmiDevBox-specific template replacements (C #define syntax).

    .DESCRIPTION
        Handles C-specific replacement patterns before core processing:
        - #define VAR_NAME "value" replacement for C header files
    #>
    param(
        [string]$Text,
        [hashtable]$Variables,
        [bool]$ReleaseMode
    )

    # Replace #define VAR_NAME ... patterns
    # Always quote values for C strings (even if they look like numbers)
    foreach ($varName in $Variables.Keys) {
        $value = $Variables[$varName]
        $pattern = "(?m)^[ \t]*#define[ \t]+$varName[ \t]+.*$"
        $replacement = "#define $varName `"$value`""
        $Text = [regex]::Replace($Text, $pattern, $replacement)
    }

    return $Text
}
