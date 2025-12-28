# DevBox Foundry

Development Kit for AmigaOS Cross-Compilation on Windows with VBCC.

## Quick Start

```powershell
# Download and run the standalone installer
irm https://github.com/vbuzzano/DevBoxFoundry/raw/main/install.ps1 | iex

# Follow the interactive wizard to create your project
cd MyProject
.\box.ps1 install   # Install packages
make                # Build
```

## For Developers

```powershell
git clone https://github.com/vbuzzano/DevBoxFoundry.git
cd DevBoxFoundry

make help       # Show all targets
make build      # Build release
```

## License

MIT License - see LICENSE file for details.
