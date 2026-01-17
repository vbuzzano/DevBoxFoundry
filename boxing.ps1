# Boxing - Common bootstrapper for boxer and box
#
# This script serves as the shared foundation for both boxer.ps1 (global manager)
# and box.ps1 (project manager). It handles:
# - Mode detection (boxer vs box)
# - Core library loading
# - Module discovery and loading
# - Command dispatching

# Strict mode for better error detection
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Global variables
$script:BoxingRoot = $PSScriptRoot
$script:Mode = $null
$script:LoadedModules = @{}
$script:Commands = @{}
$script:CommandRegistry = @{}

# Embedded flag - set to $true by build process for compiled versions
if (-not (Get-Variable -Name IsEmbedded -Scope Script -ErrorAction SilentlyContinue)) {
    $script:IsEmbedded = $false
}

# Detect execution mode
function Initialize-Mode {
    # If mode already set (by embedded script), use it
    if ($script:Mode) {
        Write-Verbose "Mode already set: $script:Mode"
        return $script:Mode
    }

    # When executed via irm|iex, $MyInvocation.PSCommandPath is empty
    # In this case, default to 'boxer' mode for installation
    if (-not $MyInvocation.PSCommandPath) {
        $script:Mode = 'boxer'
        return $script:Mode
    }

    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.PSCommandPath)

    if ($scriptName -eq 'boxer') {
        $script:Mode = 'boxer'
    }
    elseif ($scriptName -eq 'box') {
        $script:Mode = 'box'
    }
    else {
        throw "Unknown execution mode. Script must be named 'boxer.ps1' or 'box.ps1'"
    }

    return $script:Mode
}
# Load core libraries
function Import-CoreLibraries {
    # Skip if embedded version - libraries already loaded
    if ($script:IsEmbedded) {
        Write-Verbose "Embedded mode: core libraries already loaded"
        return
    }

    $corePath = Join-Path $script:BoxingRoot 'core'

    if (-not (Test-Path $corePath)) {
        throw "Core directory not found: $corePath"
    }

    $coreFiles = Get-ChildItem -Path $corePath -Filter '*.ps1' | Sort-Object Name

    foreach ($file in $coreFiles) {
        try {
            . $file.FullName
            Write-Verbose "Loaded core: $($file.Name)"
        }
        catch {
            throw "Failed to load core library $($file.Name): $_"
        }
    }
}

# Build list of external module roots by mode and priority
# box-override: External modules in .box/modules/ and modules/ override embedded modules
function Get-ExternalModuleRoots {
    param([string]$Mode)

    $roots = @()

    if ($Mode -eq 'box') {
        $projectRoot = Get-Location
        # box-override priority: custom modules before project modules
        $roots += @{ Path = Join-Path $projectRoot '.box\modules'; Source = 'custom' }
        $roots += @{ Path = Join-Path $projectRoot 'modules'; Source = 'project' }
    }
    else {
        $roots += @{ Path = Join-Path $script:BoxingRoot 'modules'; Source = 'custom' }
    }

    return $roots | Where-Object { Test-Path $_.Path }
}

# Execute handler descriptor consistently
function Invoke-HandlerDescriptor {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Descriptor,
        [object[]]$Arguments = @()
    )

    switch ($Descriptor.Type) {
        'script' {
            if ($Arguments.Count -gt 0 -and $Arguments[0] -is [hashtable]) {
                $splat = $Arguments[0]
                $rest = if ($Arguments.Count -gt 1) { $Arguments[1..($Arguments.Count - 1)] } else { @() }
                & $Descriptor.Path @splat @rest
            }
            else {
                & $Descriptor.Path @Arguments
            }
        }
        'function' {
            if ($Descriptor.ContainsKey('ModulePath') -and $Descriptor.ModulePath) {
                if (-not (Get-Command -Name $Descriptor.Function -ErrorAction SilentlyContinue)) {
                    Get-ChildItem -Path $Descriptor.ModulePath -File -Filter '*.ps1' -ErrorAction SilentlyContinue |
                        Where-Object { (Select-String -Path $_.FullName -Pattern 'function\s+' -Quiet) } |
                        ForEach-Object { . $_.FullName }
                }
            }

            if ($Arguments.Count -gt 0 -and $Arguments[0] -is [hashtable]) {
                $splat = $Arguments[0]
                $rest = if ($Arguments.Count -gt 1) { $Arguments[1..($Arguments.Count - 1)] } else { @() }
                & $Descriptor.Function @splat @rest
            }
            else {
                & $Descriptor.Function @Arguments
            }
        }
        'file-function' {
            . $Descriptor.Path

            if ($Arguments.Count -gt 0 -and $Arguments[0] -is [hashtable]) {
                $splat = $Arguments[0]
                $rest = if ($Arguments.Count -gt 1) { $Arguments[1..($Arguments.Count - 1)] } else { @() }
                & $Descriptor.Function @splat @rest
            }
            else {
                & $Descriptor.Function @Arguments
            }
        }
        default { throw "Unsupported handler type: $($Descriptor.Type)" }
    }
}

# Display help for a handler descriptor
function Show-DescriptorHelp {
    param([hashtable]$Descriptor)

    if (-not $Descriptor) { return }

    switch ($Descriptor.Type) {
        'script' { Get-Help $Descriptor.Path -ErrorAction SilentlyContinue | Out-String | Write-Output }
        'function' { Get-Help $Descriptor.Function -ErrorAction SilentlyContinue | Out-String | Write-Output }
        'file-function' {
            . $Descriptor.Path
            Get-Help $Descriptor.Function -ErrorAction SilentlyContinue | Out-String | Write-Output
        }
        default { Write-Output "No help available" }
    }
}

# Safe descriptor lookup
function Get-DescriptorField {
    param(
        [hashtable]$Descriptor,
        [string]$Key
    )

    if ($Descriptor -and $Descriptor.ContainsKey($Key)) {
        return $Descriptor[$Key]
    }

    return $null
}

# Parse metadata handler string into executable descriptor
function Resolve-MetadataHandler {
    param(
        [string]$ModulePath,
        [string]$Value
    )

    if (-not $Value) { return $null }

    if ($Value -like '*::*') {
        $parts = $Value -split '::', 2
        return @{
            Type = 'file-function'
            Path = Join-Path $ModulePath $parts[0]
            Function = $parts[1]
        }
    }

    if ($Value -like '*.ps1') {
        return @{
            Type = 'script'
            Path = Join-Path $ModulePath $Value
        }
    }

    return @{
        Type = 'function'
        Function = $Value
        ModulePath = $ModulePath
    }
}

# Register external modules (files, directories, metadata)
function Register-ExternalModules {
    param(
        [string]$Root,
        [string]$Source,
        [string]$Mode
    )

    if (-not (Test-Path $Root)) {
        return
    }

    $fileModules = Get-ChildItem -Path $Root -File -Filter '*.ps1' -ErrorAction SilentlyContinue
    foreach ($file in $fileModules) {
        $commandName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name).ToLower()

        if ($commandName -eq 'help') {
            Write-Warning "Command 'help' is reserved (builtin). Module '$($file.Name)' ignored."
            continue
        }

        if ($script:CommandRegistry.ContainsKey($commandName)) { continue }

        $script:Commands[$commandName] = $file.FullName
        $script:CommandRegistry[$commandName] = @{
            Name = $commandName
            Kind = 'external-file'
            Source = $Source
            Handler = $file.FullName
        }

        $script:LoadedModules[$file.Name] = $file.FullName
        Write-Verbose "Registered external file ($Source): $commandName"
    }

    $directories = Get-ChildItem -Path $Root -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $directories) {
        if ($Mode -and (@('box', 'boxer', 'shared') -contains $dir.Name.ToLower())) { continue }
        $metadataPath = Join-Path $dir.FullName 'metadata.psd1'
        if (Test-Path $metadataPath) {
            Register-MetadataModule -ModulePath $dir.FullName -Source $Source
        }
        else {
            Register-ExternalDirectoryModule -ModulePath $dir.FullName -ModuleName $dir.Name -Source $Source
        }
    }
}

# Register a directory-based module (no metadata)
function Register-ExternalDirectoryModule {
    param(
        [string]$ModulePath,
        [string]$ModuleName,
        [string]$Source
    )

    $commandName = $ModuleName.ToLower()

    if ($commandName -eq 'help') {
        Write-Warning "Command 'help' is reserved (builtin). Module directory '$ModuleName' ignored."
        return
    }

    $ps1Files = Get-ChildItem -Path $ModulePath -File -Filter '*.ps1' -ErrorAction SilentlyContinue
    $subcommands = @{}
    $defaultHandler = $null
    $helpHandler = $null

    foreach ($file in $ps1Files) {
        $name = $file.BaseName.ToLower()

        switch ($name) {
            'metadata' { continue }
            'help' { $helpHandler = $file.FullName; continue }
            {$name -eq $ModuleName.ToLower()} { $defaultHandler = $file.FullName; continue }
            default { $subcommands[$name] = $file.FullName }
        }
    }

    if ($script:CommandRegistry.ContainsKey($ModuleName.ToLower())) { return }

    $mappedValue = if ($defaultHandler) { $defaultHandler } else { $ModulePath }
    $script:Commands[$ModuleName.ToLower()] = $mappedValue
    $script:CommandRegistry[$ModuleName.ToLower()] = @{
        Name = $ModuleName.ToLower()
        Kind = 'external-directory'
        Source = $Source
        Subcommands = $subcommands
        DefaultHandler = $defaultHandler
        HelpHandler = $helpHandler
        Root = $ModulePath
    }

    Write-Verbose "Registered external directory ($Source): $ModuleName"
}

# Register metadata-driven module commands
function Register-MetadataModule {
    param(
        [string]$ModulePath,
        [string]$Source
    )

    $metadataPath = Join-Path $ModulePath 'metadata.psd1'

    try {
        $metadata = Import-PowerShellDataFile -Path $metadataPath
    }
    catch {
        Write-Warning "Failed to load metadata.psd1 for module at ${ModulePath}: $($_)"
        return
    }

    $missing = @()

    foreach ($key in @('ModuleName', 'Commands')) {
        if (-not $metadata.ContainsKey($key) -or -not $metadata[$key]) {
            $missing += $key
        }
    }

    if ($missing.Count -gt 0) {
        Write-Warning "Metadata module $ModulePath missing required keys: $($missing -join ', ')"
        return
    }

    $moduleName = $metadata.ModuleName

    $helpHandler = $null
    $helpFile = Join-Path $ModulePath 'help.ps1'
    if (Test-Path $helpFile) { $helpHandler = $helpFile }

    foreach ($entry in $metadata.Commands.GetEnumerator()) {
        $cmdName = $entry.Key.ToLower()

        if ($cmdName -eq 'help') {
            Write-Warning "Command 'help' is reserved (builtin). Metadata command '$cmdName' in module '$moduleName' ignored."
            continue
        }

        if ($script:CommandRegistry.ContainsKey($cmdName)) { continue }

        $config = $entry.Value
        $hasHandler = ($config.ContainsKey('Handler') -and -not [string]::IsNullOrWhiteSpace($config['Handler']))
        $hasDispatcher = ($config.ContainsKey('Dispatcher') -and -not [string]::IsNullOrWhiteSpace($config['Dispatcher']))
        $hasSubcommands = ($config.ContainsKey('Subcommands') -and $config['Subcommands'])

        if ($hasHandler -and $hasDispatcher) {
            Write-Warning "Metadata command $cmdName cannot define both Handler and Dispatcher. Skipping."
            continue
        }

        if (-not $hasHandler -and -not $hasDispatcher -and -not $hasSubcommands) {
            Write-Warning "Metadata command $cmdName must define Handler, Dispatcher, or Subcommands. Skipping."
            continue
        }

        $handler = $null
        $dispatcher = $null

        if ($hasHandler) {
            $handler = Resolve-MetadataHandler -ModulePath $ModulePath -Value $config['Handler']
            if (-not $handler) {
                Write-Warning "Metadata command $cmdName has invalid Handler. Skipping."
                continue
            }
        }

        if ($hasDispatcher) {
            $dispatcher = Resolve-MetadataHandler -ModulePath $ModulePath -Value $config['Dispatcher']
            if (-not $dispatcher) {
                Write-Warning "Metadata command $cmdName has invalid Dispatcher. Skipping."
                continue
            }
        }

        $subcommands = @{}
        if ($hasSubcommands) {
            foreach ($subEntry in $config['Subcommands'].GetEnumerator()) {
                $subValue = $subEntry.Value
                $subHandler = if ($subValue.ContainsKey('Handler')) { Resolve-MetadataHandler -ModulePath $ModulePath -Value $subValue['Handler'] } else { $null }
                if (-not $subHandler) {
                    Write-Warning "Metadata subcommand $($subEntry.Key.ToLower()) for $cmdName missing valid Handler. Skipping subcommand."
                    continue
                }
                $subcommands[$subEntry.Key.ToLower()] = @{
                    Name = $subEntry.Key.ToLower()
                    Handler = $subHandler
                    Synopsis = if ($subValue.ContainsKey('Synopsis')) { $subValue['Synopsis'] } else { $null }
                    Description = if ($subValue.ContainsKey('Description')) { $subValue['Description'] } else { $null }
                }
            }
        }

        $script:Commands[$cmdName] = $ModulePath
        $script:CommandRegistry[$cmdName] = @{
            Name = $cmdName
            Kind = 'metadata'
            Source = $Source
            ModuleName = $moduleName
            ModulePath = $ModulePath
            Handler = $handler
            Dispatcher = $dispatcher
            Subcommands = $subcommands
            HelpHandler = $helpHandler
            Synopsis = if ($config.ContainsKey('Synopsis')) { $config['Synopsis'] } else { $null }
            Description = if ($config.ContainsKey('Description')) { $config['Description'] } else { $null }
        }

        Write-Verbose "Registered metadata command ($Source): $cmdName"
    }
}

# Discover and load mode-specific modules
function Import-ModeModules {
    param([string]$Mode)

    if (-not $Mode) {
        $Mode = Initialize-Mode
    }

    $script:Mode = $Mode

    if (-not $script:CommandRegistry) {
        $script:CommandRegistry = @{}
    }

    if ($script:IsEmbedded) {
        Write-Verbose "Embedded mode: $Mode modules already loaded"
        Register-EmbeddedCommands -Mode $Mode
        return
    }

    $roots = Get-ExternalModuleRoots -Mode $Mode

    foreach ($root in $roots) {
        Register-ExternalModules -Root $root.Path -Source $root.Source -Mode $Mode
    }

    $modulesPath = Join-Path $script:BoxingRoot "modules\$Mode"

    if (Test-Path $modulesPath) {
        $moduleFiles = Get-ChildItem -Path $modulesPath -Filter '*.ps1' | Sort-Object Name

        foreach ($file in $moduleFiles) {
            try {
                . $file.FullName

                $commandName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

                if (-not $script:Commands.ContainsKey($commandName)) {
                    $script:Commands[$commandName] = $file.FullName
                }

                if (-not $script:LoadedModules.ContainsKey($file.Name)) {
                    $script:LoadedModules[$file.Name] = $file.FullName
                }

                Write-Verbose "Loaded module (embedded): $Mode/$($file.Name)"
            }
            catch {
                Write-Warning "Failed to load module $($file.Name): $_"
            }
        }
    }

    Register-EmbeddedCommands -Mode $Mode
}

# Register embedded commands (when modules are already loaded)
function Register-EmbeddedCommands {
    param([string]$Mode)

    # For embedded versions, discover commands dynamically by scanning loaded functions
    $modeName = if ($Mode) { ($Mode.Substring(0,1).ToUpper() + $Mode.Substring(1).ToLower()) } else { $Mode }
    $prefix = "Invoke-$modeName-"
    $functions = Get-Command -Name "$prefix*" -CommandType Function -ErrorAction SilentlyContinue | Sort-Object Name
    $registered = @{}

    foreach ($func in $functions) {
        $funcName = $func.Name
        $namePart = $funcName.Substring($prefix.Length)
        $commandName = ($namePart -split '-', 2)[0].ToLower()

        if ($registered.ContainsKey($commandName)) {
            Write-Verbose "Skipping duplicate embedded command: $commandName from $funcName"
            continue
        }

        if (-not $script:Commands.ContainsKey($commandName)) {
            $script:Commands[$commandName] = $funcName
        }
        $registered[$commandName] = $true

        if (-not $script:CommandRegistry.ContainsKey($commandName)) {
            # Extract synopsis from function's help comment
            $helpInfo = Get-Help $funcName -ErrorAction SilentlyContinue
            $synopsis = if ($helpInfo -and $helpInfo.Synopsis -and $helpInfo.Synopsis -ne $funcName) { 
                $helpInfo.Synopsis 
            } else { 
                $null 
            }

            $script:CommandRegistry[$commandName] = @{
                Name = $commandName
                Kind = 'embedded'
                Source = 'built-in'
                Handler = $funcName
                Path = $func.ScriptBlock.File
                Synopsis = $synopsis
            }
        }

        Write-Verbose "Registered embedded command: $commandName → $funcName"
    }
}

# Discover and load shared modules
function Import-SharedModules {
    # Skip if embedded version - shared modules already loaded
    if ($script:IsEmbedded) {
        Write-Verbose "Embedded mode: shared modules already loaded"
        return
    }

    $sharedPath = Join-Path $script:BoxingRoot 'modules\shared'

    if (-not (Test-Path $sharedPath)) {
        Write-Verbose "No shared modules found"
        return
    }

    $moduleDirs = Get-ChildItem -Path $sharedPath -Directory -Recurse

    foreach ($moduleDir in $moduleDirs) {
        $metadataPath = Join-Path $moduleDir.FullName 'metadata.psd1'
        if (-not (Test-Path $metadataPath)) {
            throw "Shared module missing metadata.psd1: $($moduleDir.FullName)"
        }

        $metadata = Import-PowerShellDataFile -Path $metadataPath

        $missingKeys = @()
        if (-not $metadata.ContainsKey('ModuleName') -or [string]::IsNullOrWhiteSpace($metadata.ModuleName)) {
            $missingKeys += 'ModuleName'
        }
        if (-not $metadata.ContainsKey('Commands') -or -not $metadata.Commands -or $metadata.Commands.Count -eq 0) {
            $missingKeys += 'Commands'
        }

        if ($missingKeys.Count -gt 0) {
            throw "Shared module $($moduleDir.FullName) missing required metadata keys: $($missingKeys -join ', ')"
        }

        $moduleName = $metadata.ModuleName
        $privateFunctions = @()
        if ($metadata.ContainsKey('PrivateFunctions')) {
            $privateFunctions = $metadata.PrivateFunctions
        }

        $moduleFiles = Get-ChildItem -Path $moduleDir.FullName -Filter '*.ps1'

        foreach ($file in $moduleFiles) {
            . $file.FullName
            Write-Verbose "Loaded shared module: $moduleName/$($file.Name)"
        }

        $missingCommands = @()
        foreach ($cmd in $metadata.Commands) {
            $boxFunc = "Invoke-Box-$cmd"
            $boxerFunc = "Invoke-Boxer-$cmd"
            $boxCmd = Get-Command -Name $boxFunc -CommandType Function -ErrorAction SilentlyContinue
            $boxerCmd = Get-Command -Name $boxerFunc -CommandType Function -ErrorAction SilentlyContinue

            $hasEntry = $false
            if ($boxCmd -and $boxCmd.ScriptBlock.File -like "$($moduleDir.FullName)*") { $hasEntry = $true }
            if ($boxerCmd -and $boxerCmd.ScriptBlock.File -like "$($moduleDir.FullName)*") { $hasEntry = $true }

            if (-not $hasEntry) {
                $missingCommands += $cmd
            }
            else {
                $script:Commands[$cmd] = $moduleName

                if (-not $script:CommandRegistry.ContainsKey($cmd)) {
                    $script:CommandRegistry[$cmd] = @{
                        Name = $cmd
                        Kind = 'embedded'
                        Source = 'built-in'
                        Handler = if ($boxCmd) { $boxFunc } elseif ($boxerCmd) { $boxerFunc } else { $null }
                    }
                }
            }
        }

        if ($missingCommands.Count -gt 0) {
            throw "Shared module $($moduleDir.FullName) missing entrypoints for commands: $($missingCommands -join ', ')"
        }

        $moduleFunctions = Get-Command -Name 'Invoke-*' -CommandType Function -ErrorAction SilentlyContinue | Where-Object { $_.ScriptBlock.File -like "$($moduleDir.FullName)*" }
        $unexpected = @()
        foreach ($func in $moduleFunctions) {
            if ($func.Name -match '^Invoke-[^-]+-(?<cmd>[^-]+)') {
                $cmdName = $matches['cmd']
                if (-not $metadata.Commands -or -not ($metadata.Commands -contains $cmdName)) {
                    if (-not ($privateFunctions -contains $cmdName)) {
                        $unexpected += $cmdName
                    }
                }
            }
        }

        if ($unexpected.Count -gt 0) {
            throw "Shared module $($moduleDir.FullName) has undeclared functions: $($unexpected -join ', ')"
        }

        $script:LoadedModules[$moduleName] = $moduleDir.FullName
    }
}

# Show available subcommands for directory/metadata modules
function Show-SubcommandHelp {
    param(
        [hashtable]$Entry
    )

    $lines = @()
    $lines += "Available subcommands for $($Entry.Name):"

    $subNames = $Entry.Subcommands.Keys | Sort-Object
    foreach ($name in $subNames) {
        $sub = $Entry.Subcommands[$name]
        $desc = ''
        if ($sub -is [hashtable]) {
            $subDescription = Get-DescriptorField -Descriptor $sub -Key 'Description'
            $subSynopsis = Get-DescriptorField -Descriptor $sub -Key 'Synopsis'
            if ($subDescription) { $desc = $subDescription }
            elseif ($subSynopsis) { $desc = $subSynopsis }
        }

        $line = "  $name"
        if ($desc) { $line += " - $desc" }
        $lines += $line
    }

    $lines | ForEach-Object { Write-Output $_ }
}

# Invoke dispatcher descriptor with explicit parameters
function Invoke-DispatcherDescriptor {
    param(
        [hashtable]$Descriptor,
        [string[]]$CommandPath,
        [string[]]$Arguments
    )

    switch ($Descriptor.Type) {
        'function' {
            if ($Descriptor.ContainsKey('ModulePath') -and $Descriptor.ModulePath) {
                if (-not (Get-Command -Name $Descriptor.Function -ErrorAction SilentlyContinue)) {
                    Get-ChildItem -Path $Descriptor.ModulePath -File -Filter '*.ps1' -ErrorAction SilentlyContinue |
                        Where-Object { (Select-String -Path $_.FullName -Pattern 'function\s+' -Quiet) } |
                        ForEach-Object { . $_.FullName }
                }
            }

            return (& $Descriptor.Function -CommandPath $CommandPath -Arguments $Arguments)
        }
        'script' {
            return (& $Descriptor.Path -CommandPath $CommandPath -Arguments $Arguments)
        }
        'file-function' {
            . $Descriptor.Path
            return (& $Descriptor.Function -CommandPath $CommandPath -Arguments $Arguments)
        }
        default {
            throw "Unsupported dispatcher type: $($Descriptor.Type)"
        }
    }
}

# Dispatch command to appropriate handler
function Invoke-Command {
    param(
        [string]$CommandName,
        [string[]]$Arguments
    )

    $normalized = $CommandName.ToLower()

    if ($normalized -eq 'help') {
        Show-Help -CommandPath $Arguments
        return
    }

    if (-not $script:CommandRegistry.ContainsKey($normalized)) {
        Write-Error "Unknown command: $CommandName"
        Show-Help
        return 1
    }

    $entry = $script:CommandRegistry[$normalized]
    $kind = Get-DescriptorField -Descriptor $entry -Key 'Kind'

    try {
        switch ($kind) {
            'embedded' {
                $handler = Get-DescriptorField -Descriptor $entry -Key 'Handler'
                $handlerPath = Get-DescriptorField -Descriptor $entry -Key 'Path'

                if (-not (Get-Command -Name $handler -ErrorAction SilentlyContinue) -and $handlerPath) {
                    . $handlerPath
                }

                return (& $handler @Arguments)
            }
            'external-file' {
                $handler = Get-DescriptorField -Descriptor $entry -Key 'Handler'
                return (& $handler @Arguments)
            }
            'external-directory' {
                $subcommands = Get-DescriptorField -Descriptor $entry -Key 'Subcommands'
                if (-not $subcommands) { $subcommands = @{} }
                $defaultHandler = Get-DescriptorField -Descriptor $entry -Key 'DefaultHandler'

                $callArgs = $Arguments
                $subName = $null
                if ($Arguments.Count -gt 0) {
                    $candidate = $Arguments[0].ToLower()
                    if ($subcommands.ContainsKey($candidate)) {
                        $subName = $candidate
                        $callArgs = if ($Arguments.Count -gt 1) { $Arguments[1..($Arguments.Count - 1)] } else { @() }
                    }
                }

                if ($subName) {
                    return (& $subcommands[$subName] @callArgs)
                }

                if ($defaultHandler) {
                    return (& $defaultHandler @Arguments)
                }

                Show-SubcommandHelp -Entry $entry
                return
            }
            'metadata' {
                $callArgs = $Arguments
                $commandPath = @($normalized)
                $subName = $null

                $subcommands = Get-DescriptorField -Descriptor $entry -Key 'Subcommands'
                if (-not $subcommands) { $subcommands = @{} }
                $dispatcher = Get-DescriptorField -Descriptor $entry -Key 'Dispatcher'
                $handler = Get-DescriptorField -Descriptor $entry -Key 'Handler'

                if ($Arguments.Count -gt 0) {
                    $candidate = $Arguments[0].ToLower()
                    if ($subcommands.ContainsKey($candidate)) {
                        $subName = $candidate
                        $commandPath += $candidate
                        $callArgs = if ($Arguments.Count -gt 1) { $Arguments[1..($Arguments.Count - 1)] } else { @() }
                    }
                }

                if ($dispatcher) {
                    if (-not $subName -and $callArgs.Count -gt 0 -and $callArgs[0] -notmatch '^-') {
                        $commandPath += $callArgs[0]
                        $callArgs = if ($callArgs.Count -gt 1) { $callArgs[1..($callArgs.Count - 1)] } else { @() }
                    }

                    return (Invoke-DispatcherDescriptor -Descriptor $dispatcher -CommandPath $commandPath -Arguments $callArgs)
                }

                if ($subName) {
                    $subHandler = Get-DescriptorField -Descriptor $subcommands[$subName] -Key 'Handler'
                    return (Invoke-HandlerDescriptor -Descriptor $subHandler -Arguments $callArgs)
                }

                if ($handler) {
                    return (Invoke-HandlerDescriptor -Descriptor $handler -Arguments $callArgs)
                }

                Show-SubcommandHelp -Entry $entry
                return
            }
            default {
                Write-Error "Unknown command kind: $($entry.Kind)"
                return 1
            }
        }
    }
    catch {
        Write-Error "Command execution failed: $_"
        return 1
    }
}

# Help system supporting embedded, external, and metadata modules
function Show-Help {
    param([string[]]$CommandPath = @())

    if (-not $CommandPath) {
        $CommandPath = @()
    }
    else {
        $CommandPath = @($CommandPath)
    }

    if (-not $CommandPath -or $CommandPath.Count -eq 0) {
        $lines = @('Available commands:')

        $entries = $script:CommandRegistry.GetEnumerator() | Sort-Object Key
        foreach ($entry in $entries) {
            $value = $entry.Value
            $synopsis = Get-DescriptorField -Descriptor $value -Key 'Synopsis'
            $name = Get-DescriptorField -Descriptor $value -Key 'Name'
            $displaySynopsis = if ($synopsis) { $synopsis } else { '' }
            $lines += ("  {0,-12} {1}" -f $name, $displaySynopsis)
        }

        foreach ($line in $lines) {
            Write-Output $line
        }
        return
    }

    $commandName = $CommandPath[0].ToLower()

    if (-not $script:CommandRegistry.ContainsKey($commandName)) {
        Write-Output "Unknown command: $commandName"
        return
    }

    $entry = $script:CommandRegistry[$commandName]
    $subPath = if ($CommandPath.Count -gt 1) { @($CommandPath[1..($CommandPath.Count - 1)]) } else { @() }
    $subPath = @($subPath)
    $kind = Get-DescriptorField -Descriptor $entry -Key 'Kind'

    switch ($kind) {
        'embedded' {
            $handler = Get-DescriptorField -Descriptor $entry -Key 'Handler'
            Get-Help $handler -ErrorAction SilentlyContinue | Out-String | Write-Output
        }
        'external-file' {
            $handler = Get-DescriptorField -Descriptor $entry -Key 'Handler'
            Get-Help $handler -ErrorAction SilentlyContinue | Out-String | Write-Output
        }
        'external-directory' {
            $subcommands = Get-DescriptorField -Descriptor $entry -Key 'Subcommands'
            if (-not $subcommands) { $subcommands = @{} }
            $helpHandler = Get-DescriptorField -Descriptor $entry -Key 'HelpHandler'
            $defaultHandler = Get-DescriptorField -Descriptor $entry -Key 'DefaultHandler'

            if ($subPath.Count -gt 0) {
                $subName = $subPath[0].ToLower()
                if ($subcommands.ContainsKey($subName)) {
                    Get-Help $subcommands[$subName] -ErrorAction SilentlyContinue | Out-String | Write-Output
                    return
                }
            }

            if ($helpHandler) {
                    $helpOutput = & $helpHandler @()
                    if ($helpOutput) { $helpOutput | ForEach-Object { Write-Output $_ } }
                return
            }

            if ($defaultHandler) {
                Get-Help $defaultHandler -ErrorAction SilentlyContinue | Out-String | Write-Output
            }
            else {
                Show-SubcommandHelp -Entry $entry
            }
        }
        'metadata' {
            $dispatcher = Get-DescriptorField -Descriptor $entry -Key 'Dispatcher'
            $subcommands = Get-DescriptorField -Descriptor $entry -Key 'Subcommands'
            if (-not $subcommands) { $subcommands = @{} }
            $helpHandler = Get-DescriptorField -Descriptor $entry -Key 'HelpHandler'
            $handler = Get-DescriptorField -Descriptor $entry -Key 'Handler'
            $name = Get-DescriptorField -Descriptor $entry -Key 'Name'

            if ($dispatcher) {
                $helpPath = @($name)
                if ($subPath.Count -gt 0) { $helpPath += $subPath }
                $helpPath += 'help'
                Invoke-DispatcherDescriptor -Descriptor $dispatcher -CommandPath $helpPath -Arguments @()
                return
            }

            if ($subPath.Count -gt 0) {
                $subName = $subPath[0].ToLower()
                if ($subcommands.ContainsKey($subName)) {
                    $subHandler = Get-DescriptorField -Descriptor $subcommands[$subName] -Key 'Handler'
                    Show-DescriptorHelp -Descriptor $subHandler
                    return
                }
            }

            if ($helpHandler) {
                $helpOutput = & $helpHandler @()
                if ($helpOutput) { $helpOutput | ForEach-Object { Write-Output $_ } }
                return
            }

            if ($handler) {
                Show-DescriptorHelp -Descriptor $handler
            }
            else {
                Show-SubcommandHelp -Entry $entry
            }
        }
        default {
            Write-Output "No help available for $commandName"
        }
    }
}

# Main bootstrapping function
function Initialize-Boxing {
    param(
        [string[]]$Arguments = @()
    )

    try {
        # Auto-installation/update if executed via irm|iex (no $PSScriptRoot)
        if (-not $PSScriptRoot -and $Arguments.Count -eq 0) {
            $BoxerInstalled = "$env:USERPROFILE\Documents\PowerShell\Boxing\boxer.ps1"

            # 1. Check if already installed
            if (Test-Path $BoxerInstalled) {
                # 2. Compare versions
                $InstalledContent = Get-Content $BoxerInstalled -Raw
                $InstalledVersion = if ($InstalledContent -match 'Version:\s*(\S+)') { $Matches[1] } else { $null }

                # Get current version via core API (works in all modes)
                $CurrentVersion = Get-BoxerVersion

                # 3. Decision: upgrade only if new version > installed version
                try {
                    if ($InstalledVersion -and $CurrentVersion -and ([version]$CurrentVersion -gt [version]$InstalledVersion)) {
                        Write-Host ""
                        Write-Host "🔄 Boxer update: $InstalledVersion → $CurrentVersion" -ForegroundColor Cyan
                        Install-BoxingSystem | Out-Null
                        return
                    } elseif ($InstalledVersion -and $CurrentVersion) {
                        # Already up-to-date or newer installed
                        Write-Host "✓ Boxer already up-to-date (v$InstalledVersion)" -ForegroundColor Green
                        # Check if box needs update (Install-BoxingSystem handles this)
                        Install-BoxingSystem | Out-Null
                        return
                    }
                } catch {
                    # Version parsing failed, skip update
                }
            } else {
                # First-time installation
                Install-BoxingSystem | Out-Null
                return
            }
        }
        # Step 1: Detect mode
        $mode = Initialize-Mode
        Write-Verbose "Mode: $mode"

        # Step 2: Load core libraries
        Import-CoreLibraries
        Write-Verbose "Core libraries loaded"

        # Step 3: Load mode-specific modules
        Import-ModeModules -Mode $mode
        Write-Verbose "Mode modules loaded: $($script:Commands.Count) commands"

        # Step 4: Load shared modules
        Import-SharedModules
        Write-Verbose "Shared modules loaded"

        # Step 5: Dispatch command
        if ($Arguments.Count -gt 0) {
            $command = $Arguments[0]
            $cmdArgs = if ($Arguments.Count -gt 1) {
                $Arguments[1..($Arguments.Count - 1)]
            } else {
                @()
            }

            $exitCode = Invoke-Command -CommandName $command -Arguments $cmdArgs
            if ($exitCode -and $exitCode -ne 0) { return $exitCode }
            return
        }
        else {
            Show-Help
            return
        }
    }
    catch {
        Write-Error "Boxing initialization failed: $_"
        return 1
    }
}
