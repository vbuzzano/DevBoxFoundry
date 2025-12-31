@{
    Name = "{{BOX_NAME}}"
    Type = "{{BOX_TYPE}}"
    Description = "Minimal box template"
    Version = "1.0.0"

    # Packages to install
    Packages = @()

    # Environment variables
    Envs = @{}

    # Workspace initialization
    InitWorkspace = $true
}
