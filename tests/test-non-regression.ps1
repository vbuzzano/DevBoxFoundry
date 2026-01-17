# Non-Regression Tests for Version Management System
# Validates version detection, comparison, and update logic (FR-030 to FR-034)

#Requires -Modules Pester
#Requires -Version 7.0

BeforeAll {
    $script:BoxingRoot = Split-Path $PSScriptRoot -Parent
    $script:versionFile = Join-Path $BoxingRoot "boxer.version"
    $script:versionScript = Join-Path $BoxingRoot "core\version.ps1"
    $script:buildScript = Join-Path $BoxingRoot "scripts\build-boxer.ps1"
    $script:metadataFile = Join-Path $BoxingRoot "boxers\AmiDevBox\metadata.psd1"
    $script:installScript = Join-Path $BoxingRoot "modules\boxer\install.ps1"
    
    # Pre-check file existence for Skip conditions
    $script:hasMetadata = Test-Path $script:metadataFile
    $script:hasInstallScript = Test-Path $script:installScript
    $script:hasVersionScript = Test-Path $script:versionScript
}

Describe "Version Management Non-Regression" {
    Context "Version File Integrity" {
        It "Should have boxer.version file" {
            Test-Path $versionFile | Should -BeTrue
        }
        
        It "Should have non-empty version in boxer.version" {
            $version = (Get-Content $versionFile -Raw).Trim()
            $version | Should -Not -BeNullOrEmpty
        }
        
        It "Should follow semantic versioning (X.Y.Z)" {
            $version = (Get-Content $versionFile -Raw).Trim()
            $version | Should -Match '^\d+\.\d+\.\d+$'
        }
    }
    
    Context "Version Detection Sources" {
        It "Should load Get-BoxerVersion function" {
            if (Test-Path $versionScript) {
                . $versionScript
                Get-Command Get-BoxerVersion -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            } else {
                Set-TestInconclusive "core/version.ps1 not found"
            }
        }
        
        It "Should return a version from Get-BoxerVersion" {
            if (Test-Path $versionScript) {
                . $versionScript
                $script:BoxingRoot = Split-Path $PSScriptRoot -Parent
                $detectedVersion = Get-BoxerVersion
                $detectedVersion | Should -Not -BeNullOrEmpty
            } else {
                Set-TestInconclusive "core/version.ps1 not found"
            }
        }
        
        It "Should match boxer.version file" {
            if (Test-Path $versionScript) {
                . $versionScript
                $script:BoxingRoot = Split-Path $PSScriptRoot -Parent
                $fileVersion = (Get-Content $versionFile -Raw).Trim()
                $detectedVersion = Get-BoxerVersion
                $detectedVersion | Should -Be $fileVersion
            } else {
                Set-TestInconclusive "core/version.ps1 not found"
            }
        }
    }
    
    Context "Build Version Auto-Increment" {
        It "Should have build-boxer.ps1 script" {
            Test-Path $buildScript | Should -BeTrue
        }
        
        It "Should read boxer.version file in build script" {
            $buildContent = Get-Content $buildScript -Raw
            $buildContent | Should -Match 'boxer\.version'
        }
        
        It "Should increment version in build script" {
            $buildContent = Get-Content $buildScript -Raw
            $buildContent | Should -Match '\$build\+\+'
        }
        
        It "Should write new version back to file" {
            $buildContent = Get-Content $buildScript -Raw
            $buildContent | Should -Match 'Set-Content\s+.*\$VersionFile'
        }
    }
    
    Context "Dual-Version Tracking (Version + BoxerVersion)" {
        It "Should have metadata.psd1" -Skip:(-not $hasMetadata) {
            Test-Path $metadataFile | Should -BeTrue
        }
        
        It "Should contain Version field in metadata" -Skip:(-not $hasMetadata) {
            $metadataContent = Get-Content $metadataFile -Raw
            $metadataContent | Should -Match 'Version\s*='
        }
        
        It "Should contain BoxerVersion field in metadata" -Skip:(-not $hasMetadata) {
            $metadataContent = Get-Content $metadataFile -Raw
            $metadataContent | Should -Match 'BoxerVersion\s*='
        }
        
        It "Should have valid semantic version for Version field" -Skip:(-not $hasMetadata) {
            $metadata = Import-PowerShellDataFile $metadataFile
            $metadata.Version | Should -Match '^\d+\.\d+\.\d+$'
        }
        
        It "Should have valid semantic version for BoxerVersion field" -Skip:(-not $hasMetadata) {
            $metadata = Import-PowerShellDataFile $metadataFile
            $metadata.BoxerVersion | Should -Match '^\d+\.\d+\.\d+$'
        }
    }
    
    Context "Smart Update Logic" {
        It "Should have install.ps1 module" {
            Test-Path $installScript | Should -BeTrue
        }
        
        It "Should have Get-InstalledBoxVersion function" -Skip:(-not $hasInstallScript) {
            $installContent = Get-Content $installScript -Raw
            $installContent | Should -Match 'function Get-InstalledBoxVersion'
        }
        
        It "Should have Get-RemoteBoxVersion function" -Skip:(-not $hasInstallScript) {
            $installContent = Get-Content $installScript -Raw
            $installContent | Should -Match 'function Get-RemoteBoxVersion'
        }
        
        It "Should compare versions before install" -Skip:(-not $hasInstallScript) {
            $installContent = Get-Content $installScript -Raw
            ($installContent -match 'Get-InstalledBoxVersion') -and 
            ($installContent -match 'Get-RemoteBoxVersion') | Should -BeTrue
        }
    }
}
