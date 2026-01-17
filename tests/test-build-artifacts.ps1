#requires -Version 7.0

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent

BeforeAll {
    $script:repoRoot = Split-Path $PSScriptRoot -Parent

    function Copy-PathIfExists {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Relative,
            [Parameter(Mandatory = $true)]
            [string]$DestinationRoot
        )

        $source = Join-Path $script:repoRoot $Relative
        $destination = Join-Path $DestinationRoot $Relative

        if (-not (Test-Path $source)) {
            return
        }

        $parent = Split-Path $destination -Parent
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        Copy-Item -Path $source -Destination $destination -Recurse -Force
    }

    function New-TestBuildWorkspace {
        $root = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        $pathsToCopy = @(
            'boxing.ps1',
            'boxer.version',
            'core',
            'modules\boxer',
            'modules\box',
            'modules\shared\pkg',
            'scripts\build-boxer.ps1',
            'scripts\build-box.ps1',
            'boxers\AmiDevBox\metadata.psd1'
        )

        foreach ($path in $pathsToCopy) {
            Copy-PathIfExists -Relative $path -DestinationRoot $root
        }

        return $root
    }
}

Describe "Build scripts produce embedded artifacts" {
    Context "build-boxer.ps1" {
        BeforeEach {
            $script:testRoot = New-TestBuildWorkspace
            Push-Location $script:testRoot
        }

        AfterEach {
            Pop-Location
            if (Test-Path $script:testRoot) {
                Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "produces boxer with embedded flag and functions" {
            $buildScript = Join-Path $testRoot 'scripts/build-boxer.ps1'
            { & $buildScript } | Should -Not -Throw

            $output = Join-Path $testRoot 'dist/boxer.ps1'
            Test-Path $output | Should -Be $true

            $content = Get-Content $output -Raw
            $content | Should -Match '\$script:IsEmbedded\s*=\s*\$true'
            $content | Should -Match 'function\s+Invoke-Boxer-Install'
            $content | Should -Not -Match 'Process-Package'
        }
    }

    Context "build-box.ps1" {
        BeforeEach {
            $script:testRoot = New-TestBuildWorkspace
            Push-Location $script:testRoot
        }

        AfterEach {
            Pop-Location
            if (Test-Path $script:testRoot) {
                Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "produces box with embedded pkg and help" {
            $buildScript = Join-Path $testRoot 'scripts/build-box.ps1'
            { & $buildScript } | Should -Not -Throw

            $output = Join-Path $testRoot 'dist/box.ps1'
            Test-Path $output | Should -Be $true

            $content = Get-Content $output -Raw
            $content | Should -Match '\$script:IsEmbedded\s*=\s*\$true'
            $content | Should -Match 'function\s+Invoke-Box-Pkg'
            $content | Should -Match 'Process-Package'
            $content | Should -Match 'Package management dispatcher'
        }
    }
}
