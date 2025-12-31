@{
    Name = "{{BOX_NAME}}"
    Type = "{{BOX_TYPE}}"
    Description = "Development box template with build tools"
    Version = "1.0.0"

    # Build directories
    Directories = @(
        "build"
        "dist"
        "src"
        "include"
        "docs"
        "scripts"
    )

    # Packages to install
    Packages = @()

    # Environment variables
    Envs = @{
        SRC_DIR = "src"
        BUILD_DIR = "build"
        DIST_DIR = "dist"
        INCLUDE_DIR = "include"
    }

    # Workspace initialization
    InitWorkspace = $true

    # Makefile template
    MakefileTemplate = "assets/Makefile.template"
}
