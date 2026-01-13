# {{BOX_NAME}}

Development box created with BoxBuilder.

## Type

{{BOX_TYPE}} - Full development environment with build tools

## Features

- Build system (Makefile)
- Source organization (src/, include/)
- Build outputs (build/, dist/)
- Documentation (docs/)
- Scripts (scripts/)

## Installation

```powershell
boxer install {{BOX_NAME}}
```

## Usage

Initialize project:
```powershell
cd your-project
box install
```

Build:
```bash
make
```

Clean:
```bash
make clean
```

## Configuration

Edit `config.psd1` to customize:
- Packages
- Environment variables
- Build directories
- Templates
