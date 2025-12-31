# ============================================================================
# Box Clean Module
# ============================================================================
#
# Handles box clean command - cleaning build artifacts

function Invoke-Box-Clean {
    <#
    .SYNOPSIS
    Cleans build artifacts from the project.

    .EXAMPLE
    box clean
    #>

    Write-Title "Cleaning Build Artifacts"

    # Clean common build directories
    $cleanDirs = @('build', 'dist', 'out', 'bin', 'obj')

    foreach ($dir in $cleanDirs) {
        $dirPath = Join-Path $BaseDir $dir
        if (Test-Path $dirPath) {
            Remove-Item $dirPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Success "Removed: $dir/"
        }
    }

    # Clean temp files
    Get-ChildItem -Path $BaseDir -Filter "*.tmp" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $BaseDir -Filter "*.log" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Success "Clean complete"
}
