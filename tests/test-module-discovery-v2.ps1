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
    }
}
