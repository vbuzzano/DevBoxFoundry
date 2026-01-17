# Module System - Overview

**Version**: 2.0
**Status**: Production
**Audience**: Developers, Module Authors

---

## Introduction

The Boxing module system provides a flexible, convention-based architecture for extending boxer and box commands. It balances simplicity for basic use cases with power for complex scenarios.

## Core Philosophy

### 1. Simple by Default

Most modules are just PowerShell scripts. No boilerplate, no mandatory structure. Drop a `.ps1` file in the right directory and it works.

**Why**: Reduces friction for users who want to add simple custom commands.

### 2. Progressive Complexity

The system supports four module types, from simplest to most complex:

1. **Single-file external module** - Just a script
2. **Directory-based module** - Multiple subcommands, auto-discovered
3. **Metadata-driven module** - Declarative routing, validation, dependencies
4. **Embedded module** - Compiled into main executable

**Why**: Choose the right tool for the job. Don't force complexity on simple tasks.

### 3. Convention Over Configuration

The system infers behavior from structure:
- File named `install.ps1` in `pkg/` directory → becomes `box pkg install`
- Function named `Invoke-Box-Env` → becomes `box env`
- File named `pkg.ps1` inside `pkg/` directory → default command for `box pkg`

**Why**: Self-documenting code, less maintenance, faster development.

### 4. PowerShell Native

Leverages PowerShell's built-in features:
- Comment-based help (`.SYNOPSIS`, `.DESCRIPTION`)
- Parameter binding and validation
- Splatting for argument forwarding
- `Get-Help` for documentation

**Why**: Don't reinvent the wheel. Users already know PowerShell.

### 5. Priority System

External modules (user-created) override embedded modules (built-in).

**Why**: Users can customize behavior without modifying source code.

### 6. Runtime Discovery

All modules discovered dynamically at startup. No hardcoded registries.

**Why**: Zero configuration. Add a file, it works immediately.

---

## Two Execution Modes

### Boxer (Global CLI)

**Purpose**: System-wide operations (installation, updates, configuration)

**Location**: Installed in PowerShell modules directory

**Modules from**:
- Embedded: Compiled into `boxer.ps1`
- External: `PowerShell/Boxing/modules/` (user custom commands)

**Example commands**:
- `boxer install` - Install boxer
- `boxer update` - Update to latest version
- `boxer config` - Configure boxer settings

### Box (Project-Specific CLI)

**Purpose**: Project-level operations (packages, environment, deployment)

**Location**: `.box/box.ps1` in project workspace

**Modules from**:
- Embedded: Compiled into `box.ps1`
- External: `.box/modules/` (box-specific custom commands)
- External: `modules/` (project-level commands)

**Example commands**:
- `box pkg install` - Install project dependencies
- `box env load` - Load project environment
- `box deploy start` - Deploy application

---

## Module Types Comparison

| Type | Complexity | Use Case | Example |
|------|-----------|----------|---------|
| **Embedded** | Low (for users) | Built-in commands shipped with boxing | `box env`, `boxer install` |
| **External Single File** | Very Low | Simple one-off commands | `box sayhi`, `box backup` |
| **External Directory** | Low | Commands with subcommands | `box pkg install/uninstall/list` |
| **Metadata Module** | Medium | Complex routing, dependencies, validation | `box docker container start` |

---

## Discovery Process

### Startup Sequence

1. **Mode Detection**: Determine if running as `box` or `boxer`
2. **Core Loading**: Load shared utilities and helpers
3. **External Module Scan**: Check user directories for custom modules
4. **Embedded Module Scan**: Register built-in functions
5. **Validation**: Verify handlers exist, resolve conflicts
6. **Ready**: CLI ready to accept commands

### Priority Rules

When multiple modules register the same command name:

1. **External modules** (`.box/modules/` or `modules/`)
2. **Embedded modules** (compiled functions)

**Result**: Users can override any built-in command by creating an external module with the same name.

---

## Command Routing

### Simple Flow

```
User types: box pkg install vscode

1. Parse: mode=box, command=pkg, subcommand=install, args=[vscode]
2. Find: Locate 'pkg' module (external or embedded)
3. Detect: Module is directory-based
4. Route: Look for install.ps1 in pkg/ directory
5. Execute: & "install.ps1" 'vscode'
```

### With Default Command

```
User types: box pkg

1. Parse: mode=box, command=pkg, no subcommand
2. Find: pkg/ directory module
3. Check: Does pkg.ps1 exist?
   - YES → Execute pkg.ps1
   - NO → Show help (list subcommands)
```

### With Metadata

```
User types: box deploy start --env prod

1. Parse: mode=box, command=deploy, subcommand=start, args=[--env, prod]
2. Find: deploy/ with metadata.psd1
3. Load: Read metadata, find handler for 'start'
4. Execute: Handler specified in metadata
```

---

## Argument Passing

### Automatic Binding

PowerShell handles all argument passing natively. No custom parsing needed.

**Script receives**:
- Positional arguments → First available parameters
- Named arguments (`--Name Value`) → Matching parameters
- Switches (`--Force`) → Boolean parameters

**Example**:
```
box pkg install vscode --Version 1.85.0

Script receives:
  $PackageName = 'vscode'
  $Version = '1.85.0'
```

### Dispatcher Exception

Custom dispatchers receive special `-CommandPath` parameter to know their invocation context.

**Purpose**: Dispatcher needs to know full command path to route correctly.

---

## Help System

### Unified Syntax

All help accessed via `help` subcommand:
- `box help` → List all commands
- `box help pkg` → Show pkg help or list subcommands
- `box help pkg install` → Show install.ps1 help

### Source Indicators

Help listings show module origin:
- `[built-in]` - Embedded module
- `[custom]` - User module in `.box/modules/`
- `[project]` - Project module in `modules/`

### Auto-Generated vs Custom

- **Default**: System extracts `.SYNOPSIS` from comment-based help
- **Custom**: Module can provide `help.ps1` for custom help display
- **Metadata**: Synopsis/Description in metadata.psd1 override file help

---

## Reserved Names

### Parameter Names

- `-CommandPath` - Reserved for dispatcher functions

### Command Names

- `help` - Built-in help system
- `version` - Show version information
- `info` - List all registered commands

### File Names

- `metadata.psd1` - Module metadata file
- `{module}.ps1` - Default command file (must match directory name)
- `help.ps1` - Custom help handler (optional)

---

## Error Handling Philosophy

### Fail Gracefully

- Invalid module → Skip, log warning, continue loading others
- Missing handler → Skip command, log error, continue
- Runtime error → Display error, exit with non-zero code

### User-Friendly Messages

Errors include:
- What went wrong
- Which module/command failed
- Suggestion for resolution (when possible)

### Continue When Possible

One broken module doesn't prevent others from working. System continues loading valid modules.

---

## Security Considerations

### Script Execution

External modules execute with same privileges as box/boxer process. Users responsible for validating script sources.

### Metadata Validation

Metadata files loaded without executing code. Safer for initial validation and security scanning.

### Isolation

Modules share PowerShell scope. No built-in sandboxing. Trust is user's responsibility.

---

## Performance Characteristics

### Startup Time

- **Fast**: External modules scanned on demand
- **Cached**: Metadata loaded once per session
- **Lazy**: Complex modules load only when invoked

### Runtime Overhead

- **Minimal**: Direct script execution (no wrapper overhead)
- **Native**: PowerShell parameter binding (optimized)
- **Efficient**: Functions already in memory (embedded modules)

---

## Development Workflow

### For Simple Commands

1. Create `.ps1` file in appropriate directory
2. Add comment-based help
3. Test with `box {command}`
4. Done

### For Complex Modules

1. Create directory structure
2. Write subcommand scripts
3. Add metadata.psd1 (optional)
4. Test routing and help
5. Refine based on usage

### For Embedded Modules (Boxing Core)

1. Write module in `DevBoxFoundry/modules/{mode}/`
2. Add comment-based help
3. Run build script
4. Test compiled executable
5. Release

---

## Next Steps

- **Module Authors**: See [Module Development Guide](./modules-development.md)
- **Embedded Modules**: See [Embedded Module Guide](./modules-embedded.md)
- **Metadata Reference**: See [Metadata Schema Reference](./modules-metadata.md)
- **Examples**: See `MODULES2.md` examples section

---

**Questions?** Check the technical specification: `MODULES2.md`
