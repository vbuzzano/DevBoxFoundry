# Test box command discovery (parent directory search)
# Validates .box/ discovery from current directory, parent, deep nesting, and not found scenarios

#Requires -Modules Pester
#Requires -Version 7.0

BeforeAll {
    # Create isolated test environment
    $script:TestRoot = Join-Path $env:TEMP "BoxDiscoveryTest_$(Get-Random)"
    New-Item -Path $TestRoot -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TestRoot) {
        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Box Discovery" {
    Context "Current directory" {
        It "Should find .box/box.ps1 in current directory" {
            # Arrange
            $projectDir = Join-Path $TestRoot 'CurrentDirTest'
            $boxDir = Join-Path $projectDir '.box'
            $boxScript = Join-Path $boxDir 'box.ps1'

            New-Item -ItemType Directory -Path $boxDir -Force | Out-Null
            Set-Content -Path $boxScript -Value 'Write-Host "Box script found!"'

            # Act
            Push-Location $projectDir
            try {
                $testPath = Join-Path (Get-Location).Path '.box\box.ps1'

                # Assert
                Test-Path $testPath | Should -BeTrue
            }
            finally {
                Pop-Location
            }
        }
    }

    Context "Parent directory discovery" {
        It "Should find .box/box.ps1 one level up" {
            # Arrange
            $projectDir = Join-Path $TestRoot 'ParentTest'
            $boxDir = Join-Path $projectDir '.box'
            $boxScript = Join-Path $boxDir 'box.ps1'
            $subDir = Join-Path $projectDir 'src'

            New-Item -ItemType Directory -Path $boxDir -Force | Out-Null
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            Set-Content -Path $boxScript -Value 'Write-Host "Box script found!"'

            # Act - Simulate discovery from subdirectory
            $current = Get-Item $subDir
            $boxFound = $false

            while ($current.FullName -ne [System.IO.Path]::GetPathRoot($current.FullName)) {
                $testPath = Join-Path $current.FullName '.box\box.ps1'
                if (Test-Path $testPath) {
                    $boxFound = $true
                    break
                }
                $parent = Split-Path $current.FullName -Parent
                if (-not $parent) { break }
                $current = Get-Item $parent
            }

            # Assert
            $boxFound | Should -BeTrue
        }
    }

    Context "Deep nesting" {
        It "Should find .box/box.ps1 five levels up" {
            # Arrange
            $projectDir = Join-Path $TestRoot 'DeepTest'
            $boxDir = Join-Path $projectDir '.box'
            $boxScript = Join-Path $boxDir 'box.ps1'
            $deepDir = Join-Path $projectDir 'src\components\ui\buttons\primary'

            New-Item -ItemType Directory -Path $boxDir -Force | Out-Null
            New-Item -ItemType Directory -Path $deepDir -Force | Out-Null
            Set-Content -Path $boxScript -Value 'Write-Host "Box script found!"'

            # Act - Simulate discovery from deep subdirectory
            $startPath = $deepDir
            $current = Get-Item $deepDir
            $boxFound = $false
            $boxPath = $null

            while ($current.FullName -ne [System.IO.Path]::GetPathRoot($current.FullName)) {
                $testPath = Join-Path $current.FullName '.box\box.ps1'
                if (Test-Path $testPath) {
                    $boxFound = $true
                    $boxPath = $current.FullName
                    break
                }
                $parent = Split-Path $current.FullName -Parent
                if (-not $parent) { break }
                $current = Get-Item $parent
            }

            # Assert
            $boxFound | Should -BeTrue

            # Calculate levels
            $startParts = $startPath.Split('\')
            $boxParts = $boxPath.Split('\')
            $levels = $startParts.Count - $boxParts.Count
            $levels | Should -Be 5
        }
    }

    Context "No .box found" {
        It "Should correctly detect when no .box/ exists in tree" {
            # Arrange
            $noBoxDir = Join-Path $TestRoot 'NoBoxTest'
            New-Item -ItemType Directory -Path $noBoxDir -Force | Out-Null

            # Act
            Push-Location $noBoxDir
            try {
                $current = Get-Location
                $boxFound = $false

                while ($current.Path -ne [System.IO.Path]::GetPathRoot($current.Path)) {
                    $testPath = Join-Path $current.Path '.box\box.ps1'
                    if (Test-Path $testPath) {
                        $boxFound = $true
                        break
                    }
                    $parent = Split-Path $current.Path -Parent
                    if (-not $parent) { break }
                    $current = Get-Item $parent
                }

                # Assert - Should NOT find .box
                $boxFound | Should -BeFalse
            }
            finally {
                Pop-Location
            }
        }
    }
}
