#Requires -Modules Pester

Describe "Pkg module" {
    BeforeAll {
        $global:BaseDir = "TestDrive:\project"
        $global:VendorDir = "TestDrive:\project\vendor"
        $global:StateFile = "TestDrive:\project\.box\state.json"
        $global:TempDir = "TestDrive:\temp"
        $global:AllPackages = @()

        New-Item -ItemType Directory -Path $global:BaseDir -Force | Out-Null
        New-Item -ItemType Directory -Path $global:VendorDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Split-Path $global:StateFile -Parent) -Force | Out-Null
        New-Item -ItemType Directory -Path $global:TempDir -Force | Out-Null

        # Initialize boxing variables
        $script:IsEmbedded = $false
        $script:BoxingRoot = Split-Path $PSScriptRoot -Parent

        . (Join-Path $PSScriptRoot "..\core\common.ps1")

        $pkgPath = Join-Path $PSScriptRoot "..\modules\shared\pkg"
        . "$pkgPath\state.ps1"
        . "$pkgPath\extraction.ps1"
        . "$pkgPath\detection.ps1"
        . "$pkgPath\dependencies.ps1"
        . "$pkgPath\install.ps1"
        . "$pkgPath\uninstall.ps1"
        . "$pkgPath\list.ps1"

        function Write-Info { param($Message) }
        function Write-Warn { param($Message) }
        function Write-Err { param($Message) }
        function Write-Success { param($Message) }
        function Ask-Choice { param($Prompt) return "Y" }
        function Ask-Path { param($Name) return "TestDrive:\path" }
    }

    Context "State Management" {
        It "should save and load state" {
            $testState = @{ packages = @{ test = @{ installed = $true } } }
            Save-State -State $testState
            $loaded = Load-State
            $loaded.packages.test.installed | Should -Be $true
        }

        It "should get package state" {
            Set-PackageState -Name "test-pkg" -Installed $true -Files @("file1") -Dirs @("dir1") -Envs @{}
            $state = Get-PackageState -Name "test-pkg"
              $state.installed | Should -Be $true
              ($state.files -contains "file1") | Should -Be $true
        }

        It "should remove package state" {
            Set-PackageState -Name "test-pkg2" -Installed $true -Files @() -Dirs @() -Envs @{}
            Remove-PackageState -Name "test-pkg2"
            $state = Get-PackageState -Name "test-pkg2"
              $state | Should -BeNullOrEmpty
        }
    }

    Context "Extraction Rules" {
        It "should parse extraction rule" {
            $rule = "copy:*.exe:vendor/tools/:TOOL_PATH"
            $parsed = Parse-ExtractRule -Rule $rule
              $parsed.Type | Should -Be "copy"
              $parsed.Pattern | Should -Be "*.exe"
              $parsed.Destination | Should -Be "vendor/tools/"
              $parsed.EnvVar | Should -Be "TOOL_PATH"
        }

        It "should extract env vars from rules" {
            $rules = @(
                "copy:bin/*:vendor/bin/:BIN_PATH",
                "copy:lib/*:vendor/lib/:LIB_PATH",
                "copy:README.md:docs/"
            )
            $envs = Get-EnvVarsFromRules -ExtractRules $rules
                ($envs.Keys -contains "BIN_PATH") | Should -Be $true
                ($envs.Keys -contains "LIB_PATH") | Should -Be $true
                $envs.Keys.Count | Should -Be 2
        }
    }

    Context "Package Detection" {
        It "should detect installed package" {
            Set-PackageState -Name "detected-pkg" -Installed $true -Files @() -Dirs @() -Envs @{}
            $pkg = @{ Name = "detected-pkg" }
            $result = Test-PackageInstalled -Package $pkg
              $result.Installed | Should -Be $true
              $result.Source | Should -Be "state"
        }

        It "should detect not installed package" {
            $pkg = @{ Name = "not-installed" }
            $result = Test-PackageInstalled -Package $pkg
              $result.Installed | Should -Be $false
        }
    }

    Context "Package Removal" {
        It "should remove package files" {
            $testFile = "TestDrive:\project\vendor\testfile.txt"
            New-Item -ItemType File -Path $testFile -Force | Out-Null

            Set-PackageState -Name "removable" -Installed $true -Files @($testFile) -Dirs @() -Envs @{}
            Remove-Package -Name "removable"

            Test-Path $testFile | Should -Be $false
            Get-PackageState -Name "removable" | Should -BeNullOrEmpty
        }
    }

    AfterAll {
        if (Test-Path "TestDrive:\project") {
            Remove-Item "TestDrive:\project" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
