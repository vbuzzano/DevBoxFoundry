#requires -Version 7.0

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..' 'boxing.ps1')

function Reset-TestState {
    param([string]$Root)

    $script:Commands = @{}
    $script:CommandRegistry = @{}
    $script:LoadedModules = @{}
    $script:IsEmbedded = $false
    $script:Mode = $null
    $script:BoxingRoot = $Root
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

            Initialize-Boxing -Arguments @('alpha', 'one', 'two') | Should Be 'custom:one,two'
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

            Initialize-Boxing -Arguments @('beta', 'a') | Should Be 'boxer:a'
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

            Invoke-Command -CommandName 'echo' -Arguments @('a', '--flag', 'b') | Should Be 'a|--flag|b'
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

            Invoke-Command -CommandName 'echoext' -Arguments @('a', '--flag', 'b') | Should Be 'a|--flag|b'
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

            Invoke-Command -CommandName 'meta' -Arguments @('x', 'y') | Should Be 'x;y'
            Invoke-Command -CommandName 'router' -Arguments @('one', 'two') | Should Be 'router>one|two'
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
            $helpOutput | Should Contain 'help-called'
        }

        It "lists subcommands when no default handler exists" {
            $dirRoot = Join-Path $testRoot '.box/modules/nodflt'
            New-Item -ItemType Directory -Path $dirRoot -Force | Out-Null
            Set-Content -Path (Join-Path $dirRoot 'one.ps1') -Encoding UTF8 -Value "'one'"
            Set-Content -Path (Join-Path $dirRoot 'two.ps1') -Encoding UTF8 -Value "'two'"

            Import-ModeModules -Mode 'box'

            $output = Invoke-Command -CommandName 'nodflt' -Arguments @()
            $output | Out-String | Should BeLike '*Available subcommands*'
            $output | Out-String | Should BeLike '*one*'
            $output | Out-String | Should BeLike '*two*'

            $help = Show-Help -CommandPath @('nodflt')
            $help | Out-String | Should BeLike '*one*'
            $help | Out-String | Should BeLike '*two*'
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
            $list | Out-String | Should BeLike '*[[]built-in[]]*'
            $list | Out-String | Should BeLike '*[[]custom[]]*'
            $list | Out-String | Should BeLike '*[[]project[]]*'
        }
    }
}
