# ============================================================================
# Help Renderer Models and Defaults
# ============================================================================
# Defines the data shapes and default values used by the unified help renderer.
# This file introduces no rendering logic to avoid behavior changes while the
# renderer is being adopted elsewhere.

$script:HelpRendererDefaults = [ordered]@{
    WrapWidth = 100
    NoCommandsMessage = 'No commands available.'
    FallbackSynopsis = 'No synopsis available.'
    FallbackDescription = 'No description available.'
    Boxer = [ordered]@{
        Title = 'Boxer'
        Description = 'Command-line toolbox manager.'
    }
    Box = [ordered]@{
        Title = 'Box'
        Description = 'Project command helper.'
    }
}

function Get-HelpDefaults {
    param(
        [ValidateSet('box', 'boxer')]
        [string]$Context
    )

    $contextDefaults = if ($Context -eq 'box') { $script:HelpRendererDefaults.Box } else { $script:HelpRendererDefaults.Boxer }

    return [ordered]@{
        Title = $contextDefaults.Title
        Description = $contextDefaults.Description
        WrapWidth = $script:HelpRendererDefaults.WrapWidth
        NoCommandsMessage = $script:HelpRendererDefaults.NoCommandsMessage
        FallbackSynopsis = $script:HelpRendererDefaults.FallbackSynopsis
        FallbackDescription = $script:HelpRendererDefaults.FallbackDescription
    }
}

function New-HelpCommandEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$Synopsis,
        [string]$Description,
        [hashtable[]]$Subcommands = @(),
        [bool]$IsHidden = $false,
        [string]$Source
    )

    $fallbacks = Get-HelpDefaults -Context 'box'
    $effectiveSynopsis = if ([string]::IsNullOrWhiteSpace($Synopsis)) { $fallbacks.FallbackSynopsis } else { $Synopsis }
    $effectiveDescription = if ([string]::IsNullOrWhiteSpace($Description)) { $fallbacks.FallbackDescription } else { $Description }

    return [ordered]@{
        Name = $Name.ToLower()
        Synopsis = $effectiveSynopsis
        Description = $effectiveDescription
        Subcommands = if ($Subcommands) { @($Subcommands) } else { @() }
        IsHidden = [bool]$IsHidden
        Source = $Source
    }
}

function New-HelpSubcommandEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$Synopsis,
        [string]$Description,
        [hashtable]$Handler
    )

    $fallbacks = Get-HelpDefaults -Context 'box'
    $effectiveSynopsis = if ([string]::IsNullOrWhiteSpace($Synopsis)) { $fallbacks.FallbackSynopsis } else { $Synopsis }
    $effectiveDescription = if ([string]::IsNullOrWhiteSpace($Description)) { $fallbacks.FallbackDescription } else { $Description }

    return [ordered]@{
        Name = $Name.ToLower()
        Synopsis = $effectiveSynopsis
        Description = $effectiveDescription
        Handler = $Handler
        Subcommands = @()
        IsHidden = $false
        Source = $null
    }
}

function New-HelpProfile {
    param(
        [ValidateSet('box', 'boxer')]
        [string]$Context,
        [string]$Title,
        [string]$Description,
        [string]$Header,
        [hashtable[]]$Commands = @()
    )

    $defaults = Get-HelpDefaults -Context $Context

    $effectiveTitle = if ([string]::IsNullOrWhiteSpace($Title)) { $defaults.Title } else { $Title }
    $effectiveDescription = if ([string]::IsNullOrWhiteSpace($Description)) { $defaults.Description } else { $Description }

    return [ordered]@{
        Context = $Context
        Title = $effectiveTitle
        Description = $effectiveDescription
        Header = $Header
        Commands = if ($Commands) { @($Commands) } else { @() }
        WrapWidth = $defaults.WrapWidth
        NoCommandsMessage = $defaults.NoCommandsMessage
    }
}

function Convert-RegistryEntryToHelpCommand {
    param(
        [hashtable]$Entry,
        [ValidateSet('box', 'boxer')]
        [string]$Context
    )

    if (-not $Entry) { return $null }

    $name = Get-DescriptorField -Descriptor $Entry -Key 'Name'
    $kind = Get-DescriptorField -Descriptor $Entry -Key 'Kind'
    $synopsis = Get-DescriptorField -Descriptor $Entry -Key 'Synopsis'
    $description = Get-DescriptorField -Descriptor $Entry -Key 'Description'
    $source = Get-DescriptorField -Descriptor $Entry -Key 'Source'
    $isHidden = [bool](Get-DescriptorField -Descriptor $Entry -Key 'Hidden')

    $subcommands = switch ($kind) {
        'external-directory' { Convert-RegistrySubcommands -Subcommands (Get-DescriptorField -Descriptor $Entry -Key 'Subcommands') -Context $Context }
        'metadata' { Convert-RegistrySubcommands -Subcommands (Get-DescriptorField -Descriptor $Entry -Key 'Subcommands') -Context $Context }
        Default { @() }
    }

    return New-HelpCommandEntry -Name $name -Synopsis $synopsis -Description $description -Subcommands $subcommands -IsHidden $isHidden -Source $source
}

function Convert-RegistrySubcommands {
    param(
        [hashtable]$Subcommands,
        [ValidateSet('box', 'boxer')]
        [string]$Context
    )

    if (-not $Subcommands) { return @() }

    $results = @()
    foreach ($key in ($Subcommands.Keys | Sort-Object)) {
        $value = $Subcommands[$key]
        $handler = $null
        $synopsis = $null
        $description = $null

        if ($value -is [string]) {
            $handler = @{ Type = 'script'; Path = $value }
        }
        elseif ($value -is [hashtable]) {
            $handler = Get-DescriptorField -Descriptor $value -Key 'Handler'
            $synopsis = Get-DescriptorField -Descriptor $value -Key 'Synopsis'
            $description = Get-DescriptorField -Descriptor $value -Key 'Description'
            if (-not $handler -and $value.ContainsKey('Path')) { $handler = @{ Type = 'script'; Path = $value['Path'] } }
        }

        $results += New-HelpSubcommandEntry -Name $key -Synopsis $synopsis -Description $description -Handler $handler
    }

    return $results
}

function Get-HelpRegistrySnapshot {
    param(
        [ValidateSet('box', 'boxer')]
        [string]$Context,
        [hashtable]$Registry
    )

    $commands = @()

    if (-not $Registry) { return $commands }

    foreach ($entry in $Registry.GetEnumerator() | Sort-Object Key) {
        $command = Convert-RegistryEntryToHelpCommand -Entry $entry.Value -Context $Context
        if ($command -and -not $command.IsHidden) {
            $commands += $command
        }
    }

    return $commands
}

function New-HelpProfileFromRegistry {
    param(
        [ValidateSet('box', 'boxer')]
        [string]$Context,
        [hashtable]$Registry,
        [string]$Title,
        [string]$Description,
        [string]$Header
    )

    $commands = Get-HelpRegistrySnapshot -Context $Context -Registry $Registry
    return New-HelpProfile -Context $Context -Title $Title -Description $Description -Header $Header -Commands $commands
}

function Wrap-Text {
    param(
        [string]$Text,
        [int]$Width,
        [string]$Indent = ''
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return @('') }
    $words = $Text -split '\s+'
    $lines = @()
    $current = ''

    foreach ($word in $words) {
        if ($current.Length -eq 0) {
            $current = $word
            continue
        }

        if (($current.Length + 1 + $word.Length) -le $Width) {
            $current = "$current $word"
        }
        else {
            $lines += $current
            $current = $word
        }
    }

    if ($current.Length -gt 0) { $lines += $current }

    if ($Indent) {
        return $lines | ForEach-Object { "$Indent$_" }
    }

    return $lines
}

function Render-HelpProfile {
    param(
        [hashtable]$Profile
    )

    if (-not $Profile) { return @() }

    $lines = @()

    if ($Profile.Header) {
        $headerLines = $Profile.Header -split "`n"
        $lines += $headerLines
        $lines += ''
    }

    $titleLines = Wrap-Text -Text $Profile.Title -Width $Profile.WrapWidth
    $descriptionLines = Wrap-Text -Text $Profile.Description -Width $Profile.WrapWidth

    $lines += $titleLines
    $lines += $descriptionLines
    $lines += ''
    $lines += 'Available commands:'

    $commands = @($Profile.Commands)

    if (-not $commands -or $commands.Count -eq 0) {
        $lines += "  $($Profile.NoCommandsMessage)"
        return $lines
    }

    $nameWidth = 16
    $textWidth = [Math]::Max(20, $Profile.WrapWidth - ($nameWidth + 2))

    foreach ($cmd in ($commands | Sort-Object Name)) {
        $wrapped = @(Wrap-Text -Text $cmd.Synopsis -Width $textWidth)
        if (-not $wrapped -or $wrapped.Count -eq 0) { $wrapped = @('') }

        $lines += ("  {0,-$nameWidth} {1}" -f $cmd.Name, $wrapped[0])

        if ($wrapped.Count -gt 1) {
            for ($i = 1; $i -lt $wrapped.Count; $i++) {
                $lines += ("  {0,-$nameWidth} {1}" -f '', $wrapped[$i])
            }
        }
    }

    return $lines
}

function Render-CommandHelp {
    param(
        [hashtable]$Entry,
        [hashtable]$Profile,
        [string[]]$SubPath = @()
    )

    if (-not $Entry -or -not $Profile) { return @() }

    $lines = @()
    $wrap = $Profile.WrapWidth
    $nameWidth = 16
    $textWidth = [Math]::Max(20, $wrap - ($nameWidth + 2))

    $title = if ($Entry.Name) { $Entry.Name } else { 'Command' }
    $desc = if ($Entry.Description) { $Entry.Description } else { $Profile.Description }

    $lines += Wrap-Text -Text $title -Width $wrap
    $lines += Wrap-Text -Text $desc -Width $wrap
    $lines += ''

    $subcommands = @($Entry.Subcommands)

    if ($subcommands.Count -eq 0) {
        return $lines
    }

    $lines += 'Available subcommands:'

    foreach ($sub in ($subcommands | Sort-Object Name)) {
        $wrapped = @(Wrap-Text -Text $sub.Synopsis -Width $textWidth)
        if (-not $wrapped -or $wrapped.Count -eq 0) { $wrapped = @('') }

        $lines += ("  {0,-$nameWidth} {1}" -f $sub.Name, $wrapped[0])

        if ($wrapped.Count -gt 1) {
            for ($i = 1; $i -lt $wrapped.Count; $i++) {
                $lines += ("  {0,-$nameWidth} {1}" -f '', $wrapped[$i])
            }
        }
    }

    return $lines
}
