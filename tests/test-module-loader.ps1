#requires -Version 7.0

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..' 'boxing.ps1')

BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'boxing.ps1')
    . "$PSScriptRoot/fixtures/modules-gap/helpers.ps1"
}

Describe "Module loader (modules-gap)" {
    BeforeEach {
        $script:Commands = @{}
        $script:LoadedModules = @{}
        $script:IsEmbedded = $false
        $script:Mode = $null

        $testRoot = New-MgTempRoot
        Push-Location $testRoot
        $script:BoxingRoot = $testRoot
    }

    AfterEach {
        Get-Command -Name 'Invoke-*' -CommandType Function -ErrorAction SilentlyContinue |
            Where-Object { $_.ScriptBlock.File -and $_.ScriptBlock.File -like "$($testRoot)*" } |
            ForEach-Object { Remove-Item -Path ("Function:{0}" -f $_.Name) -ErrorAction SilentlyContinue }
        Pop-Location
        if ($testRoot -and (Test-Path $testRoot)) {
            Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "User Story 1 - discovery contract" {
        It "fails when shared module metadata is missing" {
            New-MgSharedModule -Root $testRoot -ModuleName 'pkg' -Commands @('pkg') -SkipMetadata

            $errorRecord = $null
            try {
                Import-SharedModules
            }
            catch {
                $errorRecord = $_
            }

            $errorRecord | Should -Not -Be $null
            $errorRecord.Exception.Message | Should -Match 'metadata.psd1'
        }

        It "fails when required metadata keys are missing" {
            New-MgSharedModule -Root $testRoot -ModuleName 'pkg' -Commands @('pkg') -MissingKeys @('Commands')

            $errorRecord = $null
            try {
                Import-SharedModules
            }
            catch {
                $errorRecord = $_
            }

            $errorRecord | Should -Not -Be $null
            $errorRecord.Exception.Message | Should -Match 'missing required metadata keys'
        }

        It "prefers project override over core module" {
            $overridePath = New-MgModeModule -Root $testRoot -Mode 'box' -CommandName 'alpha' -Override
            $corePath = New-MgModeModule -Root $testRoot -Mode 'box' -CommandName 'alpha'

            Import-ModeModules -Mode 'box'

            $script:Commands['alpha'] | Should -Match '\\.box\\modules\\alpha.ps1'
            $script:LoadedModules['alpha.ps1'] | Should -Be $overridePath
        }
    }

    Context "User Story 2 - metadata alignment" {
        It "blocks metadata commands without entrypoints" {
            New-MgSharedModule -Root $testRoot -ModuleName 'pkg' -Commands @('pkg') -SkipFunctions

            $errorRecord = $null
            try {
                Import-SharedModules
            }
            catch {
                $errorRecord = $_
            }

            $errorRecord | Should -Not -Be $null
            $errorRecord.Exception.Message | Should -Match 'missing entrypoints'
            $errorRecord.Exception.Message | Should -Match 'pkg'
        }

        It "blocks functions not declared in metadata unless private" {
            New-MgSharedModule -Root $testRoot -ModuleName 'pkg' -Commands @('pkg') -ExtraFunctions @('hidden')

            $errorRecord = $null
            try {
                Import-SharedModules
            }
            catch {
                $errorRecord = $_
            }

            $errorRecord | Should -Not -Be $null
            $errorRecord.Exception.Message | Should -Match 'undeclared functions'
            $errorRecord.Exception.Message | Should -Match 'hidden'
        }
    }

    Context "User Story 3 - embedded parity" {
        It "matches disk discovery for base commands in embedded scan" {
            New-MgModeModule -Root $testRoot -Mode 'box' -CommandName 'alpha'
            New-MgModeModule -Root $testRoot -Mode 'box' -CommandName 'beta'

            Import-ModeModules -Mode 'box'
            $expected = @($script:Commands.Keys | Sort-Object)

            $script:Commands = @{}
            $script:LoadedModules = @{}
            $script:IsEmbedded = $true

            Get-ChildItem -Path (Join-Path $testRoot 'modules/box') -Filter '*.ps1' |
                ForEach-Object { . $_.FullName }

            Register-EmbeddedCommands -Mode 'box'

            $script:Commands.Keys | Sort-Object | Should -Be $expected
        }

        It "strips subcommand suffixes and dedupes base commands in embedded mode" {
            $script:IsEmbedded = $true
            $script:Commands = @{}
            $script:LoadedModules = @{}

            $pkgFile = Join-Path $testRoot 'modules/box/pkg.ps1'
            New-Item -ItemType Directory -Path (Split-Path $pkgFile) -Force | Out-Null
            Set-Content -Path $pkgFile -Encoding UTF8 -Value @"
function Invoke-Box-Pkg-Install { 'install' }
function Invoke-Box-Pkg-List { 'list' }
function Invoke-Box-Pkg-Validate-State { 'validate-state' }
"@

            . $pkgFile

            Register-EmbeddedCommands -Mode 'box'

            $cmds = $script:Commands.Keys | Sort-Object
            $cmds | Should -Be @('pkg')
        }
    }
}
