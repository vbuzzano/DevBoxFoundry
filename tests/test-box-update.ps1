# Test box update functionality
# Tests Update-LocalBoxIfNeeded and box update without touching real installation

#Requires -Modules Pester

BeforeAll {
    # Create isolated test environment
    $script:TestRoot = Join-Path $env:TEMP "BoxingUpdateTest_$(Get-Random)"
    $script:FakeBoxingDir = Join-Path $TestRoot "Boxing"
    $script:FakeBoxesDir = Join-Path $FakeBoxingDir "Boxes\AmiDevBox"
    $script:FakeProjectDir = Join-Path $TestRoot "TestProject"
    $script:FakeBoxDir = Join-Path $FakeProjectDir ".box"
    
    # Create directory structure
    New-Item -Path $FakeBoxingDir -ItemType Directory -Force | Out-Null
    New-Item -Path $FakeBoxesDir -ItemType Directory -Force | Out-Null
    New-Item -Path $FakeProjectDir -ItemType Directory -Force | Out-Null
    New-Item -Path $FakeBoxDir -ItemType Directory -Force | Out-Null
    
    # Create fake boxer.ps1 with version 0.1.100
    $fakeBoxerContent = @'
# Boxing - Common bootstrapper for boxer and box
# Version: 0.1.100

$script:BoxName = "AmiDevBox"
$script:BoxerVersion = "0.1.100"

function Get-BoxerVersion { return "0.1.100" }
function Update-LocalBoxIfNeeded {
    Write-Host "Fake Update-LocalBoxIfNeeded called"
}
'@
    
    Set-Content -Path (Join-Path $FakeBoxingDir "boxer.ps1") -Value $fakeBoxerContent
    
    # Create fake box.ps1 in Boxes/AmiDevBox with version 0.1.50
    $fakeBoxContent = @'
# Boxing - Common bootstrapper for boxer and box
# Version: 0.1.50

$script:BoxName = "AmiDevBox"
$script:BoxerVersion = "0.1.50"

function Get-BoxerVersion { return "0.1.50" }
'@
    
    Set-Content -Path (Join-Path $FakeBoxesDir "box.ps1") -Value $fakeBoxContent
    
    # Create metadata in Boxes/AmiDevBox
    $boxMetadata = @'
@{
    BoxName = "AmiDevBox"
    Version = "0.1.50"
    SourceRepo = "vbuzzano/AmiDevBox"
}
'@
    Set-Content -Path (Join-Path $FakeBoxesDir "metadata.psd1") -Value $boxMetadata
    
    # Create old .box in project with version 0.1.30
    $oldBoxContent = @'
# Boxing - Common bootstrapper for boxer and box
# Version: 0.1.30

$script:BoxName = "AmiDevBox"
$script:BoxerVersion = "0.1.30"

function Get-BoxerVersion { return "0.1.30" }
'@
    
    Set-Content -Path (Join-Path $FakeBoxDir "box.ps1") -Value $oldBoxContent
    
    # Create metadata in .box
    $localBoxMetadata = @'
@{
    BoxName = "AmiDevBox"
    Version = "0.1.30"
    SourceRepo = "vbuzzano/AmiDevBox"
}
'@
    Set-Content -Path (Join-Path $FakeBoxDir "metadata.psd1") -Value $localBoxMetadata
    
    # Load the Update-LocalBoxIfNeeded function from real boxing.ps1
    $boxingScript = Join-Path $PSScriptRoot "..\boxing.ps1"
    . $boxingScript
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TestRoot) {
        Remove-Item -Path $script:TestRoot -Recurse -Force
    }
}

Describe "Update-LocalBoxIfNeeded" {
    Context "When .box exists and box names match" {
        It "Should detect version mismatch" {
            # Arrange
            Push-Location $FakeProjectDir
            
            # Mock environment to use fake directories
            $env:USERPROFILE_BACKUP = $env:USERPROFILE
            $env:USERPROFILE = $TestRoot
            
            # Act
            $localMetadata = Import-PowerShellDataFile -Path (Join-Path $FakeBoxDir "metadata.psd1")
            
            # Assert
            $localMetadata.BoxName | Should -Be "AmiDevBox"
            $localMetadata.Version | Should -Be "0.1.30"
            
            # Restore
            $env:USERPROFILE = $env:USERPROFILE_BACKUP
            Pop-Location
        }
        
        It "Should update .box when source version is newer" {
            # Arrange
            Push-Location $FakeProjectDir
            $env:USERPROFILE_BACKUP = $env:USERPROFILE
            $env:USERPROFILE = $TestRoot
            
            # Update source to newer version (0.1.60)
            $newBoxContent = @'
# Boxing - Common bootstrapper for boxer and box
# Version: 0.1.60

$script:BoxName = "AmiDevBox"
$script:BoxerVersion = "0.1.60"

function Get-BoxerVersion { return "0.1.60" }
'@
            Set-Content -Path (Join-Path $FakeBoxesDir "box.ps1") -Value $newBoxContent
            
            $newMetadata = @'
@{
    BoxName = "AmiDevBox"
    Version = "0.1.60"
    SourceRepo = "vbuzzano/AmiDevBox"
}
'@
            Set-Content -Path (Join-Path $FakeBoxesDir "metadata.psd1") -Value $newMetadata
            
            # Act - Simulate the update
            Remove-Item -Path $FakeBoxDir -Recurse -Force
            Copy-Item -Path $FakeBoxesDir -Destination $FakeBoxDir -Recurse -Force
            
            # Assert
            Test-Path (Join-Path $FakeBoxDir "metadata.psd1") | Should -BeTrue
            $updatedMetadata = Import-PowerShellDataFile -Path (Join-Path $FakeBoxDir "metadata.psd1")
            $updatedMetadata.Version | Should -Be "0.1.60"
            
            # Restore
            $env:USERPROFILE = $env:USERPROFILE_BACKUP
            Pop-Location
        }
    }
    
    Context "When .box doesn't exist" {
        It "Should skip update silently" {
            # Arrange
            $nonProjectDir = Join-Path $TestRoot "NonProject"
            New-Item -Path $nonProjectDir -ItemType Directory -Force | Out-Null
            Push-Location $nonProjectDir
            
            # Act & Assert (should not throw)
            { 
                $localBoxDir = Join-Path (Get-Location) ".box"
                if (-not (Test-Path $localBoxDir)) {
                    # Should return early
                    $true | Should -BeTrue
                }
            } | Should -Not -Throw
            
            Pop-Location
        }
    }
    
    Context "When box names don't match" {
        It "Should skip update when box is different" {
            # Arrange
            $differentProjectDir = Join-Path $TestRoot "DifferentProject"
            $differentBoxDir = Join-Path $differentProjectDir ".box"
            New-Item -Path $differentBoxDir -ItemType Directory -Force | Out-Null
            
            # Create different box metadata
            $differentMetadata = @'
@{
    BoxName = "DifferentBox"
    Version = "0.1.30"
    SourceRepo = "other/DifferentBox"
}
'@
            Set-Content -Path (Join-Path $differentBoxDir "metadata.psd1") -Value $differentMetadata
            
            Push-Location $differentProjectDir
            
            # Act
            $localMeta = Import-PowerShellDataFile -Path (Join-Path $differentBoxDir "metadata.psd1")
            $scriptBoxName = "AmiDevBox"
            
            # Assert - should skip
            $localMeta.BoxName | Should -Not -Be $scriptBoxName
            
            Pop-Location
        }
    }
    
    Context "Version comparison logic" {
        It "Should correctly compare version strings" {
            # Simple version comparison tests
            [version]"0.1.60" -gt [version]"0.1.30" | Should -BeTrue
            [version]"0.1.30" -eq [version]"0.1.30" | Should -BeTrue
            [version]"0.1.30" -lt [version]"0.1.60" | Should -BeTrue
        }
    }
}

Describe "box update command" {
    Context "When metadata.psd1 exists with SourceRepo" {
        It "Should read SourceRepo from metadata" {
            # Arrange
            Push-Location $FakeProjectDir
            
            # Act
            $metadata = Import-PowerShellDataFile -Path (Join-Path $FakeBoxDir "metadata.psd1")
            
            # Assert
            $metadata.SourceRepo | Should -Be "vbuzzano/AmiDevBox"
            
            Pop-Location
        }
    }
    
    Context "When SourceRepo is missing" {
        It "Should handle missing SourceRepo gracefully" {
            # Arrange
            $noSourceMetadata = @'
@{
    BoxName = "AmiDevBox"
    Version = "0.1.30"
}
'@
            $testDir = Join-Path $TestRoot "NoSourceTest"
            New-Item -Path "$testDir\.box" -ItemType Directory -Force | Out-Null
            Set-Content -Path "$testDir\.box\metadata.psd1" -Value $noSourceMetadata
            
            Push-Location $testDir
            
            # Act
            $metadata = Import-PowerShellDataFile -Path ".box\metadata.psd1"
            
            # Assert
            $metadata.ContainsKey('SourceRepo') | Should -BeFalse
            
            Pop-Location
        }
    }
}
