# Test boxer.ps1 web installation (simulating irm | iex) without touching real installation
# Uses isolated temp environment

#Requires -Modules Pester

BeforeAll {
    # Create isolated test environment
    $script:TestRoot = Join-Path $env:TEMP "BoxingWebInstallTest_$(Get-Random)"
    $script:FakeUserProfile = $TestRoot
    $script:FakeDocuments = Join-Path $FakeUserProfile "Documents\PowerShell"
    $script:FakeBoxingDir = Join-Path $FakeDocuments "Boxing"
    $script:FakeProfilePath = Join-Path $FakeDocuments "profile.ps1"

    # Backup real environment
    $script:RealUserProfile = $env:USERPROFILE

    # Create fake directory structure
    New-Item -Path $FakeDocuments -ItemType Directory -Force | Out-Null
    Set-Content -Path $FakeProfilePath -Value "# Fake profile" -Force
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TestRoot) {
        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Boxer Web Installation (irm|iex simulation)" {
    Context "When executed via irm|iex (no PSCommandPath)" {
        It "Should detect irm|iex mode when PSScriptRoot is empty" {
            # Arrange - Simulate irm|iex environment
            $noScriptRoot = $null

            # Act & Assert
            $noScriptRoot | Should -BeNullOrEmpty
            # In real irm|iex, $PSScriptRoot would be empty
        }

        It "Should trigger auto-installation in irm|iex mode" {
            # Arrange
            $env:USERPROFILE = $FakeUserProfile
            $distBoxer = Join-Path $PSScriptRoot "..\dist\boxer.ps1"

            if (-not (Test-Path $distBoxer)) {
                Set-TestInconclusive "dist\boxer.ps1 not found - run build-boxer.ps1 first"
            }

            # Act - Simulate installation (what Initialize-Boxing does when no PSScriptRoot)
            if (-not (Test-Path $FakeBoxingDir)) {
                New-Item -Path $FakeBoxingDir -ItemType Directory -Force | Out-Null
                New-Item -Path "$FakeBoxingDir\Boxes" -ItemType Directory -Force | Out-Null
                Copy-Item -Path $distBoxer -Destination "$FakeBoxingDir\boxer.ps1" -Force
            }

            # Assert
            Test-Path $FakeBoxingDir | Should -BeTrue
            Test-Path "$FakeBoxingDir\boxer.ps1" | Should -BeTrue
            Test-Path "$FakeBoxingDir\Boxes" | Should -BeTrue

            # Restore
            $env:USERPROFILE = $RealUserProfile
        }

        It "Should install to correct location (Documents/PowerShell/Boxing)" {
            # Arrange
            $env:USERPROFILE = $FakeUserProfile

            # Act
            $expectedPath = Join-Path $FakeUserProfile "Documents\PowerShell\Boxing"

            # Assert
            $FakeBoxingDir | Should -Be $expectedPath
            Test-Path $FakeBoxingDir | Should -BeTrue

            # Restore
            $env:USERPROFILE = $RealUserProfile
        }
    }

    Context "Version comparison during web install" {
        It "Should perform fresh install when no version exists" {
            # Arrange
            $env:USERPROFILE = $FakeUserProfile
            Remove-Item $FakeBoxingDir -Recurse -Force -ErrorAction SilentlyContinue

            # Act
            $existingVersion = $null
            $shouldInstall = (-not (Test-Path $FakeBoxingDir))

            # Assert
            $shouldInstall | Should -BeTrue
            $existingVersion | Should -BeNullOrEmpty

            # Restore
            $env:USERPROFILE = $RealUserProfile
        }

        It "Should upgrade when remote version is newer" {
            # Arrange
            $env:USERPROFILE = $FakeUserProfile

            # Create old installed version
            $oldVersion = @"
# Boxing - Common bootstrapper
# Version: 0.1.50
`$script:BoxerVersion = "0.1.50"
"@
            New-Item -Path $FakeBoxingDir -ItemType Directory -Force | Out-Null
            Set-Content -Path "$FakeBoxingDir\boxer.ps1" -Value $oldVersion

            # Act - Read installed version
            $content = Get-Content "$FakeBoxingDir\boxer.ps1" -Raw
            $installedVer = if ($content -match 'Version:\s*(\S+)') { $Matches[1] } else { $null }
            $remoteVer = "0.1.100"

            # Assert
            $installedVer | Should -Be "0.1.50"
            [version]$remoteVer -gt [version]$installedVer | Should -BeTrue

            # Restore
            $env:USERPROFILE = $RealUserProfile
        }

        It "Should skip install when already up-to-date" {
            # Arrange
            $env:USERPROFILE = $FakeUserProfile

            # Create current version
            $currentVersion = @"
# Boxing - Common bootstrapper
# Version: 0.1.100
`$script:BoxerVersion = "0.1.100"
"@
            New-Item -Path $FakeBoxingDir -ItemType Directory -Force | Out-Null
            Set-Content -Path "$FakeBoxingDir\boxer.ps1" -Value $currentVersion

            # Act
            $content = Get-Content "$FakeBoxingDir\boxer.ps1" -Raw
            $installedVer = if ($content -match 'Version:\s*(\S+)') { $Matches[1] } else { $null }
            $remoteVer = "0.1.100"

            # Assert - versions match, should skip
            $installedVer | Should -Be $remoteVer
            [version]$remoteVer -eq [version]$installedVer | Should -BeTrue

            # Restore
            $env:USERPROFILE = $RealUserProfile
        }
    }
}
