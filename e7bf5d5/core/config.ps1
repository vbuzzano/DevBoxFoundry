# ============================================================================
# Configuration Management
# ============================================================================
#
# This file contains configuration merge utilities extracted from common.ps1

function Merge-Hashtable {
    <#
    .SYNOPSIS
    Recursively merges two hashtables.

    .DESCRIPTION
    Merges Override into Base, with Override values taking precedence.
    - Nested hashtables are merged recursively
    - Arrays are concatenated (Override first for priority)
    - Other values are replaced by Override

    .PARAMETER Base
    The base hashtable

    .PARAMETER Override
    The override hashtable

    .EXAMPLE
    $merged = Merge-Hashtable -Base $defaults -Override $userConfig
    #>
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )

    $result = $Base.Clone()

    foreach ($key in $Override.Keys) {
        $overrideValue = $Override[$key]

        if ($result.ContainsKey($key)) {
            $baseValue = $result[$key]

            # Both are hashtables -> recursive merge
            if ($baseValue -is [hashtable] -and $overrideValue -is [hashtable]) {
                $result[$key] = Merge-Hashtable $baseValue $overrideValue
            }
            # Both are arrays -> concatenate (Override first for priority)
            elseif ($baseValue -is [array] -and $overrideValue -is [array]) {
                $result[$key] = $overrideValue + $baseValue
            }
            # Override replaces base
            else {
                $result[$key] = $overrideValue
            }
        }
        else {
            # New key from override
            $result[$key] = $overrideValue
        }
    }

    return $result
}

function Merge-Config {
    <#
    .SYNOPSIS
    Merges system configuration with user configuration.

    .DESCRIPTION
    Convenience wrapper around Merge-Hashtable for config merging.

    .PARAMETER SysConfig
    System/default configuration

    .PARAMETER UserConfig
    User configuration (overrides)

    .EXAMPLE
    $config = Merge-Config -SysConfig $sysConfig -UserConfig $userConfig
    #>
    param(
        [hashtable]$SysConfig,
        [hashtable]$UserConfig
    )

    return Merge-Hashtable $SysConfig $UserConfig
}
