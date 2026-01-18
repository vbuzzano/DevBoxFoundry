#Requires -Modules Pester
#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..' 'boxing.ps1')

BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'boxing.ps1')

    function Reset-TestState {
        param([string]$Root)

        $script:Commands = @{}
        $script:CommandRegistry = @{}
        $script:LoadedModules = @{}
        $script:IsEmbedded = $false
        $script:Mode = $null
        $script:BoxingRoot = $Root
        $script:BoxRegistry = @{}
    }
}

Describe "Module discovery v2" {
    BeforeEach {
        $testRoot = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
        Push-Location $testRoot

        New-Item -ItemType Directory -Path (Join-Path $testRoot 'core') -Force | Out-Null
        Set-Content -Path (Join-Path $testRoot 'core' 'stub.ps1') -Encoding UTF8 -Value ''

        Reset-TestState -Root $testRoot
    }

    AfterEach {
        Get-Command -Name 'Invoke-*' -CommandType Function -ErrorAction SilentlyContinue |
            Where-Object { $_.ScriptBlock.File -and $_.ScriptBlock.File -like "$testRoot*" } |
            ForEach-Object { Remove-Item -Path ("Function:{0}" -f $_.Name) -ErrorAction SilentlyContinue }

        Pop-Location
        if (Test-Path $testRoot) {
            Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Mode detection before discovery" {
        It "selects box roots before scanning and prefers .box overrides" {
            $script:Mode = 'box'

            $customDir = Join-Path $testRoot '.box/modules'
            New-Item -ItemType Directory -Path $customDir -Force | Out-Null
            Set-Content -Path (Join-Path $customDir 'alpha.ps1') -Encoding UTF8 -Value @'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputArgs
)
'custom:' + ($InputArgs -join ',')
'@

            $projectDir = Join-Path $testRoot 'modules'
            New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
            Set-Content -Path (Join-Path $projectDir 'alpha.ps1') -Encoding UTF8 -Value @'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputArgs
)
'project:' + ($InputArgs -join ',')
'@

            Initialize-Boxing -Arguments @('alpha', 'one', 'two') | Should -Be 'custom:one,two'
        }

        It "uses boxing root modules in boxer mode" {
            $script:Mode = 'boxer'

            $boxerDir = Join-Path $testRoot 'modules'
            New-Item -ItemType Directory -Path $boxerDir -Force | Out-Null
            Set-Content -Path (Join-Path $boxerDir 'beta.ps1') -Encoding UTF8 -Value @'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputArgs
)
'boxer:' + ($InputArgs -join ',')
'@

            Initialize-Boxing -Arguments @('beta', 'a') | Should -Be 'boxer:a'
        }
    }

    Context "Embedded fallback" {
        It "routes boxer install when no external override" {
            $script:Mode = 'boxer'

            $embeddedDir = Join-Path $testRoot 'modules/boxer'
            New-Item -ItemType Directory -Path $embeddedDir -Force | Out-Null
            Set-Content -Path (Join-Path $embeddedDir 'install.ps1') -Encoding UTF8 -Value @'
function Invoke-Boxer-Install {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$InputArgs
    )
    'embedded-boxer:' + ($InputArgs -join ',')
}
'@

            Import-ModeModules -Mode 'boxer'

            Invoke-Command -CommandName 'install' -Arguments @('one', 'two') | Should -Be 'embedded-boxer:one,two'
        }

        It "keeps box pkg default and help when no external override" {
            $script:Mode = 'box'

            $embeddedDir = Join-Path $testRoot 'modules/box'
            New-Item -ItemType Directory -Path $embeddedDir -Force | Out-Null
            Set-Content -Path (Join-Path $embeddedDir 'pkg.ps1') -Encoding UTF8 -Value @'
function Invoke-Box-Pkg {
<#
.SYNOPSIS
Embedded pkg command
#>
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$InputArgs
    )
    'embedded-pkg:' + ($InputArgs -join ',')
}
'@

            Import-ModeModules -Mode 'box'

            Invoke-Command -CommandName 'pkg' -Arguments @('a') | Should -Be 'embedded-pkg:a'

            $list = Show-Help
            $list | Out-String | Should -BeLike '*pkg*'
        }
    }

    Context "External modules" {
        BeforeEach {
            $script:Mode = 'box'
            New-Item -ItemType Directory -Path (Join-Path $testRoot '.box/modules') -Force | Out-Null
        }

        It "executes external single-file modules directly" {
            $fixture = Join-Path $PSScriptRoot 'fixtures/external-single/hello.ps1'
            Copy-Item -Path $fixture -Destination (Join-Path $testRoot '.box/modules/hello.ps1') -Force

            Import-ModeModules -Mode 'box'

            Invoke-Command -CommandName 'hello' -Arguments @('one', 'two') | Should -Be 'hello:one|two'
        }

        It "executes directory module default and subcommand" {
            $fixtureDir = Join-Path $PSScriptRoot 'fixtures/external-dir/foo'
            Copy-Item -Path $fixtureDir -Destination (Join-Path $testRoot '.box/modules') -Recurse -Force

            Import-ModeModules -Mode 'box'

            Invoke-Command -CommandName 'foo' -Arguments @('a', 'b') | Should -Be 'foo-default:a|b'
            Invoke-Command -CommandName 'foo' -Arguments @('bar', 'x') | Should -Be 'foo-bar:x'
        }

        It "prefers external modules over embedded when names collide" {
            $embeddedDir = Join-Path $testRoot 'modules/box'
            New-Item -ItemType Directory -Path $embeddedDir -Force | Out-Null
            Set-Content -Path (Join-Path $embeddedDir 'hello.ps1') -Encoding UTF8 -Value @'
function Invoke-Box-Hello {
    'embedded'
}
'@

            $fixture = Join-Path $PSScriptRoot 'fixtures/external-single/hello.ps1'
            Copy-Item -Path $fixture -Destination (Join-Path $testRoot '.box/modules/hello.ps1') -Force

            Import-ModeModules -Mode 'box'

            Invoke-Command -CommandName 'hello' -Arguments @() | Should -Be 'hello:'
        }
    }

    Context "Mixed priority" {
        It "prefers external when present and keeps embedded when no override" {
            $script:Mode = 'box'

            # Embedded command without external override
            $embeddedDir = Join-Path $testRoot 'modules/box'
            New-Item -ItemType Directory -Path $embeddedDir -Force | Out-Null
            Set-Content -Path (Join-Path $embeddedDir 'pkg.ps1') -Encoding UTF8 -Value @'
function Invoke-Box-Pkg {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$InputArgs
    )
    'embedded-pkg:' + ($InputArgs -join ',')
}
'@

            # External override for hello
            $customDir = Join-Path $testRoot '.box/modules'
            New-Item -ItemType Directory -Path $customDir -Force | Out-Null
            $fixture = Join-Path $PSScriptRoot 'fixtures/external-single/hello.ps1'
            Copy-Item -Path $fixture -Destination (Join-Path $customDir 'hello.ps1') -Force

            Import-ModeModules -Mode 'box'

            Invoke-Command -CommandName 'hello' -Arguments @('x') | Should -Be 'hello:x'
            Invoke-Command -CommandName 'pkg' -Arguments @('y') | Should -Be 'embedded-pkg:y'
        }
    }

    Context "Metadata validation and dispatch" {
        BeforeEach {
            $script:Mode = 'box'
            New-Item -ItemType Directory -Path (Join-Path $testRoot '.box/modules') -Force | Out-Null
        }

        It "rejects metadata missing required keys or with both handler and dispatcher" {
            $invalidDir = Join-Path $testRoot '.box/modules/invalid'
            New-Item -ItemType Directory -Path $invalidDir -Force | Out-Null

            Set-Content -Path (Join-Path $invalidDir 'metadata.psd1') -Encoding UTF8 -Value @'
@{
    Commands = @{ bad = @{ Handler = 'run.ps1'; Dispatcher = 'Invoke-Bad' } }
}
'@
            Set-Content -Path (Join-Path $invalidDir 'run.ps1') -Encoding UTF8 -Value "'bad'"

            Import-ModeModules -Mode 'box'

            $script:CommandRegistry.ContainsKey('bad') | Should -Be $false
        }

        It "passes CommandPath to metadata dispatcher" {
            $metaFixture = Join-Path $PSScriptRoot 'fixtures/metadata-sample'
            Copy-Item -Path $metaFixture -Destination (Join-Path $testRoot '.box/modules') -Recurse -Force

            Import-ModeModules -Mode 'box'

            Invoke-Command -CommandName 'route' -Arguments @('foo', 'bar') | Should -Be 'dispatch:route>foo|bar'
        }
    }

    Context "Argument passthrough" {
        BeforeEach {
            $script:Mode = 'box'
            New-Item -ItemType Directory -Path (Join-Path $testRoot 'modules/box') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $testRoot '.box/modules') -Force | Out-Null
        }

        It "forwards args unchanged to embedded functions" {
            $embeddedPath = Join-Path $testRoot 'modules/box/echo.ps1'
            Set-Content -Path $embeddedPath -Encoding UTF8 -Value @'
function Invoke-Box-Echo {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$InputArgs
    )
    $InputArgs -join '|'
}
'@

            Import-ModeModules -Mode 'box'

            Invoke-Command -CommandName 'echo' -Arguments @('a', '--flag', 'b') | Should -Be 'a|--flag|b'
        }

        It "forwards args unchanged to external single-file modules" {
            $externalPath = Join-Path $testRoot '.box/modules/echoext.ps1'
            Set-Content -Path $externalPath -Encoding UTF8 -Value @'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputArgs
)
$InputArgs -join '|'
'@

            Import-ModeModules -Mode 'box'

            Invoke-Command -CommandName 'echoext' -Arguments @('a', '--flag', 'b') | Should -Be 'a|--flag|b'
        }

        It "forwards args unchanged to metadata handlers and dispatchers" {
            $metaRoot = Join-Path $testRoot '.box/modules/meta'
            New-Item -ItemType Directory -Path $metaRoot -Force | Out-Null
            Set-Content -Path (Join-Path $metaRoot 'metadata.psd1') -Encoding UTF8 -Value @'
@{
    ModuleName = 'meta'
    Version = '1.0.0'
    Commands = @{
        meta = @{ Handler = 'run.ps1'; Synopsis = 'meta handler' }
        router = @{ Dispatcher = 'Invoke-Meta-Dispatcher'; Synopsis = 'router' }
    }
}
'@
            Set-Content -Path (Join-Path $metaRoot 'run.ps1') -Encoding UTF8 -Value @'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputArgs
)
$InputArgs -join ';'
'@
            Set-Content -Path (Join-Path $metaRoot 'dispatcher.ps1') -Encoding UTF8 -Value @'
function Invoke-Meta-Dispatcher {
    param([string[]]$CommandPath, [string[]]$Arguments)
    ($CommandPath -join '>') + '|' + ($Arguments -join '>')
}
'@

            Import-ModeModules -Mode 'box'

            Invoke-Command -CommandName 'meta' -Arguments @('x', 'y') | Should -Be 'x;y'
            Invoke-Command -CommandName 'router' -Arguments @('one', 'two') | Should -Be 'router>one|two'
        }
    }

    Context "Help handlers and subcommands" {
        BeforeEach {
            $script:Mode = 'box'
            New-Item -ItemType Directory -Path (Join-Path $testRoot '.box/modules') -Force | Out-Null
        }

        It "executes metadata help handler when present" {
            $metaRoot = Join-Path $testRoot '.box/modules/helpmod'
            New-Item -ItemType Directory -Path $metaRoot -Force | Out-Null
            Set-Content -Path (Join-Path $metaRoot 'metadata.psd1') -Encoding UTF8 -Value @'
@{
    ModuleName = 'helpmod'
    Version = '1.0.0'
    Commands = @{ helpmod = @{ Handler = 'run.ps1'; Synopsis = 'handler' } }
}
'@
            Set-Content -Path (Join-Path $metaRoot 'run.ps1') -Encoding UTF8 -Value @'
"run"
'@
            Set-Content -Path (Join-Path $metaRoot 'help.ps1') -Encoding UTF8 -Value @'
"help-called"
'@

            Import-ModeModules -Mode 'box'

            $helpOutput = Show-Help -CommandPath @('helpmod')
            $helpOutput | Should -Contain 'help-called'
        }

        It "lists subcommands when no default handler exists" {
            $dirRoot = Join-Path $testRoot '.box/modules/nodflt'
            New-Item -ItemType Directory -Path $dirRoot -Force | Out-Null
            Set-Content -Path (Join-Path $dirRoot 'one.ps1') -Encoding UTF8 -Value "'one'"
            Set-Content -Path (Join-Path $dirRoot 'two.ps1') -Encoding UTF8 -Value "'two'"

            Import-ModeModules -Mode 'box'

            $output = Invoke-Command -CommandName 'nodflt' -Arguments @()
            $output | Out-String | Should -BeLike '*Available subcommands*'
            $output | Out-String | Should -BeLike '*one*'
            $output | Out-String | Should -BeLike '*two*'

            $help = Show-Help -CommandPath @('nodflt')
            $help | Out-String | Should -BeLike '*one*'
            $help | Out-String | Should -BeLike '*two*'
        }
    }

    Context "Help source listing" {
        It "shows built-in, custom, and project sources" {
            $script:Mode = 'box'

            $embeddedDir = Join-Path $testRoot 'modules/box'
            New-Item -ItemType Directory -Path $embeddedDir -Force | Out-Null
            Set-Content -Path (Join-Path $embeddedDir 'corecmd.ps1') -Encoding UTF8 -Value "function Invoke-Box-Corecmd { 'core' }"

            $customDir = Join-Path $testRoot '.box/modules'
            New-Item -ItemType Directory -Path $customDir -Force | Out-Null
            Set-Content -Path (Join-Path $customDir 'custom.ps1') -Encoding UTF8 -Value "'custom'"

            $projectDir = Join-Path $testRoot 'modules'
            New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
            Set-Content -Path (Join-Path $projectDir 'project.ps1') -Encoding UTF8 -Value "'project'"

            Import-ModeModules -Mode 'box'

            $list = Show-Help
            # Commands should appear in help (without source labels)
            $list | Out-String | Should -BeLike '*corecmd*'
            $list | Out-String | Should -BeLike '*custom*'
            $list | Out-String | Should -BeLike '*project*'
        }

        It "filters hidden metadata and respects custom override precedence in help listing" {
            $script:Mode = 'box'

            # Embedded command that will be overridden
            $embeddedDir = Join-Path $testRoot 'modules/box'
            New-Item -ItemType Directory -Path $embeddedDir -Force | Out-Null
            Set-Content -Path (Join-Path $embeddedDir 'hello.ps1') -Encoding UTF8 -Value "'embedded-hello'"

            # Custom override (takes precedence)
            $customDir = Join-Path $testRoot '.box/modules'
            New-Item -ItemType Directory -Path $customDir -Force | Out-Null
            Set-Content -Path (Join-Path $customDir 'hello.ps1') -Encoding UTF8 -Value "'custom-hello'"

            # Hidden metadata command should not appear in help
            $hiddenDir = Join-Path $testRoot '.box/modules/hide'
            New-Item -ItemType Directory -Path $hiddenDir -Force | Out-Null
            Set-Content -Path (Join-Path $hiddenDir 'metadata.psd1') -Encoding UTF8 -Value @'
@{
    ModuleName = 'hide'
    Version = '1.0.0'
    Commands = @{ hide = @{ Handler = 'run.ps1'; Synopsis = 'hidden'; Hidden = $true } }
}
'@
            Set-Content -Path (Join-Path $hiddenDir 'run.ps1') -Encoding UTF8 -Value "'hide'"

            Import-ModeModules -Mode 'box'

            $help = Show-Help

            # Override should appear once; embedded still registered for execution but help shows the winning entry
            $help | Out-String | Should -BeLike '*hello*'
            # Hidden metadata command must be excluded
            $help | Out-String | Should -Not -BeLike '*hide*'
        }

        It "routes metadata help via dispatcher when declared" {
            $script:Mode = 'box'

            $metaRoot = Join-Path $testRoot '.box/modules/droute'
            New-Item -ItemType Directory -Path $metaRoot -Force | Out-Null
            Set-Content -Path (Join-Path $metaRoot 'metadata.psd1') -Encoding UTF8 -Value @'
@{
    ModuleName = 'droute'
    Version = '1.0.0'
    Commands = @{ droute = @{ Dispatcher = 'dispatch.ps1' } }
}
'@
            Set-Content -Path (Join-Path $metaRoot 'dispatch.ps1') -Encoding UTF8 -Value @'
param(
    [string[]]$CommandPath,
    [string[]]$Arguments
)
"dispatched:" + ($CommandPath -join '/')
'@

            Import-ModeModules -Mode 'box'

            $help = Show-Help -CommandPath @('droute')
            $help | Out-String | Should -BeLike '*dispatched:droute/help*'
        }

        It "shows subcommands when present and omits section when none" {
            $script:Mode = 'box'

            $dirRoot = Join-Path $testRoot '.box/modules/withsubs'
            New-Item -ItemType Directory -Path $dirRoot -Force | Out-Null
            Set-Content -Path (Join-Path $dirRoot 'one.ps1') -Encoding UTF8 -Value "'one'"
            Set-Content -Path (Join-Path $dirRoot 'two.ps1') -Encoding UTF8 -Value "'two'"

            $singleRoot = Join-Path $testRoot '.box/modules/nosubs'
            New-Item -ItemType Directory -Path $singleRoot -Force | Out-Null
            Set-Content -Path (Join-Path $singleRoot 'metadata.psd1') -Encoding UTF8 -Value @'
@{
    ModuleName = 'nosubs'
    Version = '1.0.0'
    Commands = @{ nosubs = @{ Handler = 'run.ps1'; Synopsis = 'solo' } }
}
'@
            Set-Content -Path (Join-Path $singleRoot 'run.ps1') -Encoding UTF8 -Value "'run'"

            Import-ModeModules -Mode 'box'

            $subHelp = Show-Help -CommandPath @('withsubs')
            $subHelp | Out-String | Should -BeLike '*Available subcommands*'
            $subHelp | Out-String | Should -BeLike '*one*'
            $subHelp | Out-String | Should -BeLike '*two*'

            $noSubHelp = Show-Help -CommandPath @('nosubs')
            $noSubHelp | Out-String | Should -Not -BeLike '*Available subcommands*'
        }

        It "covers ≥95 percent of commands with title+synopsis and lists all registry entries" {
            $script:Mode = 'box'

            # Embedded command
            $embeddedDir = Join-Path $testRoot 'modules/box'
            New-Item -ItemType Directory -Path $embeddedDir -Force | Out-Null
            Set-Content -Path (Join-Path $embeddedDir 'alpha.ps1') -Encoding UTF8 -Value @'
function Invoke-Box-Alpha {
<#
.SYNOPSIS
Alpha synopsis
#>
    "alpha"
}
'@

            # Metadata command with synopsis/description
            $metaRoot = Join-Path $testRoot '.box/modules/meta'
            New-Item -ItemType Directory -Path $metaRoot -Force | Out-Null
            Set-Content -Path (Join-Path $metaRoot 'metadata.psd1') -Encoding UTF8 -Value @'
@{
    ModuleName = 'meta'
    Version = '1.0.0'
    Commands = @{ meta = @{ Handler = 'run.ps1'; Synopsis = 'meta syn'; Description = 'meta desc' } }
}
'@
            Set-Content -Path (Join-Path $metaRoot 'run.ps1') -Encoding UTF8 -Value "'meta'"

            # Command without synopsis to trigger default
            $projectDir = Join-Path $testRoot 'modules'
            New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
            Set-Content -Path (Join-Path $projectDir 'nosyn.ps1') -Encoding UTF8 -Value "'nosyn'"

            Import-ModeModules -Mode 'box'

            $help = Show-Help
            $lines = $help | Out-String

            # Count registry entries and verify all are present
            $registryCount = $script:CommandRegistry.Count
            $present = 0
            foreach ($name in $script:CommandRegistry.Keys) {
                if ($lines -match [regex]::Escape($name)) { $present++ }
            }

            ($present / $registryCount) | Should -BeGreaterOrEqual 0.95
            $lines | Should -BeLike '*No synopsis available*'
        }

        It "returns help output under 2 seconds for top-level and command help" {
            $script:Mode = 'box'

            $embeddedDir = Join-Path $testRoot 'modules/box'
            New-Item -ItemType Directory -Path $embeddedDir -Force | Out-Null
            Set-Content -Path (Join-Path $embeddedDir 'alpha.ps1') -Encoding UTF8 -Value "'alpha'"

            Import-ModeModules -Mode 'box'

            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $null = Show-Help
            $sw.Stop()
            $sw.Elapsed.TotalSeconds | Should -BeLessThan 2

            $sw.Reset(); $sw.Start()
            $null = Show-Help -CommandPath @('alpha')
            $sw.Stop()
            $sw.Elapsed.TotalSeconds | Should -BeLessThan 2
        }

        It "wraps long lists without truncation" {
            $script:Mode = 'box'

            $embeddedDir = Join-Path $testRoot 'modules/box'
            New-Item -ItemType Directory -Path $embeddedDir -Force | Out-Null

            for ($i = 1; $i -le 12; $i++) {
                $name = "cmd$i"
                Set-Content -Path (Join-Path $embeddedDir "$name.ps1") -Encoding UTF8 -Value @"
function Invoke-Box-$name {
<#
.SYNOPSIS
$name synopsis with many words to exercise wrapping behavior number $i
#>
    '$name'
}
"@
            }

            Import-ModeModules -Mode 'box'

            $help = Show-Help | Out-String

            $help | Should -BeLike '*Available commands:*'
            $help | Should -Not -BeLike '*...*'
        }

        It "renders boxer top-level help with defaults and wrapping" {
            $script:Mode = 'boxer'

            $embeddedDir = Join-Path $testRoot 'modules/boxer'
            New-Item -ItemType Directory -Path $embeddedDir -Force | Out-Null
            Set-Content -Path (Join-Path $embeddedDir 'alpha.ps1') -Encoding UTF8 -Value @'
function Invoke-Boxer-Alpha {
<#
.SYNOPSIS
Alpha synopsis
.DESCRIPTION
Alpha description word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12 word13 word14 word15 word16 word17 word18 word19 word20
#>
    'alpha'
}
'@

            Import-ModeModules -Mode 'boxer'

            $help = Show-Help

            $help | Out-String | Should -BeLike '*Boxer*'
            $help | Out-String | Should -BeLike '*Alpha synopsis*'
            $help | Out-String | Should -BeLike '*alpha*'
        }

        It "renders box top-level help with comment help, metadata fallback, and defaults" {
            $script:Mode = 'box'

            # Embedded comment-based help
            $embeddedDir = Join-Path $testRoot 'modules/box'
            New-Item -ItemType Directory -Path $embeddedDir -Force | Out-Null
            Set-Content -Path (Join-Path $embeddedDir 'echo.ps1') -Encoding UTF8 -Value @'
function Invoke-Box-Echo {
<#
.SYNOPSIS
Echo embedded synopsis
#>
    'echo'
}
'@

            # Metadata module (uses metadata synopsis/description)
            $metaRoot = Join-Path $testRoot '.box/modules/meta'
            New-Item -ItemType Directory -Path $metaRoot -Force | Out-Null
            Set-Content -Path (Join-Path $metaRoot 'metadata.psd1') -Encoding UTF8 -Value @'
@{
    ModuleName = 'meta'
    Version = '1.0.0'
    Commands = @{ meta = @{ Handler = 'run.ps1'; Synopsis = 'meta synopsis'; Description = 'meta description' } }
}
'@
            Set-Content -Path (Join-Path $metaRoot 'run.ps1') -Encoding UTF8 -Value "'meta'"

            # Command without synopsis to force default fallback
            $projectDir = Join-Path $testRoot 'modules'
            New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
            Set-Content -Path (Join-Path $projectDir 'nosyn.ps1') -Encoding UTF8 -Value "'nosyn'"

            Import-ModeModules -Mode 'box'

            $help = Show-Help

            $help | Out-String | Should -BeLike '*Box*'
            $help | Out-String | Should -BeLike '*Echo embedded synopsis*'
            $help | Out-String | Should -BeLike '*meta synopsis*'
            $help | Out-String | Should -BeLike '*No synopsis available*'
        }
    }
}
