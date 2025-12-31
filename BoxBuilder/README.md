# BoxBuilder

Creates new box structures for the Boxing system.

## Usage

```powershell
.\BoxBuilder\create-box.ps1 -Name "MyBox" -Type "dev"
```

## Templates

- **minimal**: Bare-bones box structure
- **dev**: Full development environment with build system
- **custom**: Customizable template (WIP)

## Parameters

- `-Name`: Name of the box (required)
- `-Type`: Template type (default: minimal)
- `-Path`: Output directory (default: boxers/)

## Examples

Create minimal box:
```powershell
.\BoxBuilder\create-box.ps1 -Name "SimpleBox"
```

Create development box:
```powershell
.\BoxBuilder\create-box.ps1 -Name "AmiDevBox" -Type "dev"
```

Create box in custom location:
```powershell
.\BoxBuilder\create-box.ps1 -Name "TestBox" -Path "my-boxes"
```

## Structure

Created boxes follow this structure:
```
boxers/MyBox/
├── config.psd1        # Box configuration
├── metadata.psd1      # Build metadata
├── README.md          # Documentation
├── assets/            # Templates
│   ├── .gitignore.template
│   ├── Makefile.template
│   └── README.md.template
└── workspace/         # Initial project structure
    ├── .vscode/
    ├── docs/
    ├── scripts/
    └── src/
```
