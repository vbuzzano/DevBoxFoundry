# Boxing

Toolkit for creating **reproducible workspace environments** (boxes). Package tools, configurations, and workflows once (e.g., AmiDevBox, ImaMap) and reproduce identically across machines. Modular, versionable, automated.

**Quick start**: `boxer install AmiDevBox`

## Vision

Generic workspace creation tool with modular packages. Create any type of development environment (Amiga/VBCC, Python, Node.js, or any other stack) through composable modules and BoxBuilder. Cross-platform support planned.

## Components

- **boxer.ps1**: Global box manager (install, list, configure boxes)
- **box.ps1**: Project workspace manager (install packages, manage environment)
- **BoxBuilder**: Create new boxes from templates (minimal, dev, custom)
- **boxes/**: Collection of available boxes (AmiDevBox, etc.)

## Creating Boxes

Use BoxBuilder to create new boxes:

```powershell
.\BoxBuilder\create-box.ps1 -Name "MyBox" -Type "dev"
```

See [BoxBuilder/README.md](BoxBuilder/README.md) for details.

## Available Boxes

- **AmiDevBox**: Amiga 68k development (VBCC, NDK 3.9, tools)
- More boxes coming soon...

## License

MIT License - see LICENSE file for details.
