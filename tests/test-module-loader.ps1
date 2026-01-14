#requires -Version 7.0

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/fixtures/modules-gap/helpers.ps1"
. (Join-Path $PSScriptRoot '..' 'boxing.ps1')

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

            $errorRecord | Should Not Be $null
            $errorRecord.Exception.Message | Should Match 'metadata.psd1'
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

            $errorRecord | Should Not Be $null
            $errorRecord.Exception.Message | Should Match 'missing required metadata keys'
        }

        It "prefers project override over core module" {
            $overridePath = New-MgModeModule -Root $testRoot -Mode 'box' -CommandName 'alpha' -Override
            $corePath = New-MgModeModule -Root $testRoot -Mode 'box' -CommandName 'alpha'

            Import-ModeModules -Mode 'box'

            $script:Commands['alpha'] | Should Match '\\.box\\modules\\alpha.ps1'
            $script:LoadedModules['alpha.ps1'] | Should Be $overridePath
        }
    }

    Context "User Story 2 - metadata alignment" {
        # Tests added in Phase 4
    }

    Context "User Story 3 - embedded parity" {
        # Tests added in Phase 5
    }
}
