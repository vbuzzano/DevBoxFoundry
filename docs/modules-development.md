# Module Development Guide

**Audience**: Module Authors
**Level**: Beginner to Advanced

---

## Getting Started

### Choose Your Module Type

**Need a simple command?** → Single-file external module
**Multiple related commands?** → Directory-based module
**Complex routing or dependencies?** → Metadata module
**Contributing to boxing core?** → Embedded module

---

## Single-File External Module

### When to Use

- Simple utility command
- One-off task automation
- Quick custom script

### Structure

One file: `{command}.ps1` in modules directory

**For boxer**: `PowerShell/Boxing/modules/mycommand.ps1`
**For box**: `.box/modules/mycommand.ps1` or `modules/mycommand.ps1`

### Best Practices

#### Always Include Help

Use PowerShell comment-based help at the top of your script.

**Minimum required**:
- `.SYNOPSIS` - Brief one-line description
- `.PARAMETER` - Document each parameter
- `.EXAMPLE` - Show at least one usage example

#### Use Parameter Validation

Leverage PowerShell's built-in validators:
- `[Parameter(Mandatory=$true)]` for required params
- `[ValidateSet('option1','option2')]` for enum-like values
- `[ValidateScript({Test-Path $_})]` for custom validation

#### Handle Errors Properly

- Use `try/catch` for expected failures
- Throw meaningful error messages
- Exit with appropriate codes (0 = success, non-zero = failure)

#### Keep It Simple

If logic gets complex, consider splitting into directory-based module or adding metadata.

---

## Directory-Based Module

### When to Use

- Command has multiple subcommands
- Shared functionality between subcommands
- Cleaner organization than single large file

### Structure

```
modules/{command}/
├── {command}.ps1      (optional - default command)
├── subcommand1.ps1
├── subcommand2.ps1
└── helpers/           (optional)
    └── shared.ps1
```

### Naming Conventions

**Command directory**: Match the main command name exactly
**Subcommand files**: Match subcommand name exactly
**Default file**: Must match directory name (e.g., `pkg/pkg.ps1`)

### Auto-Discovery

System automatically discovers:
- All `.ps1` files in root of command directory → subcommands
- Help from `.SYNOPSIS` in each file
- Available subcommands for help listings

### Default Command Pattern

**With default**: `pkg/pkg.ps1` exists
- `box pkg` → Executes `pkg.ps1`
- `box pkg install` → Executes `install.ps1`

**Without default**: No `pkg.ps1`
- `box pkg` → Shows help (lists: install, uninstall, list, etc.)
- `box pkg install` → Executes `install.ps1`

**Use default for**:
- Showing status/summary
- Most common operation
- Interactive mode

### Sharing Code Between Subcommands

**Option 1: Dot-source helper files**

```
In install.ps1:
. "$PSScriptRoot/helpers/validate.ps1"
Validate-Package $PackageName
```

**Option 2: Use metadata module** (see next section)

Metadata modules auto-source all files, making functions available everywhere.

---

## Metadata Module

### When to Use

- Custom routing logic needed
- Module has dependencies
- Need validation hooks
- Multi-level subcommands (e.g., `docker container start`)
- Want declarative configuration

### Structure

```
modules/{command}/
├── metadata.psd1      (required)
├── handler1.ps1
├── handler2.ps1
└── helpers/
    └── utilities.ps1
```

### Metadata File Basics

**Minimum viable metadata**:
- `ModuleName` - Unique identifier
- `Version` - Semantic version
- `Commands` - At least one command with handler and synopsis

### Command Definition Patterns

#### Simple Command

Maps command to single handler:
- Handler specified → Routes to that script/function
- Synopsis required → Shows in help listings

#### Command with Subcommands

Two approaches:

**1. Default + Subcommands** (recommended for mixed usage)
- Handler at command level → Default behavior
- Subcommands → Specific operations
- Example: `docker image` shows status, `docker image pull` pulls image

**2. Subcommands Only** (recommended for pure multi-command)
- No handler at command level → Forces subcommand selection
- Shows help automatically when called without subcommand
- Example: `docker container` requires subcommand

### Handler Types

**Script path**: `Handler = 'install.ps1'`
→ Executes script directly

**Function name**: `Handler = 'Install-Package'`
→ Calls function (must exist in module)

**File::Function**: `Handler = 'helpers/manager.ps1::Process-Install'`
→ Sources specific file, calls function

**Dispatcher**: `Dispatcher = 'Invoke-MyDispatcher'`
→ Custom routing (receives `-CommandPath` parameter)

### When to Use Dispatcher

**Consider dispatcher when**:
- Dynamic subcommand routing needed
- Complex conditional logic
- Subcommands discovered at runtime
- Need full control over help

**Dispatcher contract**:
- Must accept `-CommandPath` parameter (array of command segments)
- Must accept remaining arguments
- Responsible for all routing including help

### Auto-Sourcing

With metadata, system automatically:
1. Dot-sources all `.ps1` files in module directory
2. Makes all functions available to handlers
3. Respects `PrivateFunctions` list (not exposed as commands)

**Benefit**: No manual dot-sourcing needed between files.

---

## Embedded Modules

### When to Use

- Core boxing functionality
- Commands needed by all users
- Part of official distribution

### Development Location

Source in: `DevBoxFoundry/modules/{mode}/{command}.ps1`

Where `{mode}` is:
- `boxer/` - Boxer-only commands
- `box/` - Box-only commands
- `shared/` - Utility functions (not CLI commands)

### Build Process

1. Source file written as standalone script with comment-based help
2. Build script wraps in `function Invoke-{Mode}-{Command} { ... }`
3. Compiled into monolithic `boxer.ps1` or `box.ps1`
4. Function auto-discovered at runtime

### Naming Pattern

**Source file**: Any valid filename
**Built function**: `Invoke-{Mode}-{Command}`

Examples:
- `modules/boxer/install.ps1` → `Invoke-Boxer-Install`
- `modules/box/env.ps1` → `Invoke-Box-Env`
- `modules/box/pkg/install.ps1` → `Invoke-Box-Pkg-Install`

### Writing Embedded Modules

**Key difference from external**: Function wrapper added during build.

Write as if it's a standalone script:
- Include comment-based help
- Define parameters
- Write logic
- No function wrapper needed (build does it)

### Shared Utilities

**Location**: `modules/shared/`

**Purpose**: Code reuse between boxer and box modules during development

**Behavior**: Compiled as private functions in both executables

**Important**: Not available at runtime to external modules

---

## Testing Your Module

### Manual Testing

**Basic execution**:
1. Create module file(s)
2. Run command: `box mycommand args`
3. Verify output and behavior

**Help testing**:
1. Run: `box help mycommand`
2. Verify synopsis appears correctly
3. Check full help with examples

**Error testing**:
1. Try invalid arguments
2. Test missing required parameters
3. Verify error messages are clear

### Automated Testing

Consider creating test script in `tests/`:
- Test successful execution
- Test error conditions
- Validate help output
- Check argument binding

### Debug Mode

**Verbose output**:
Set `$VerbosePreference = 'Continue'` in your module to see detailed execution.

**Trace execution**:
Use `Write-Verbose` to log key decision points in your logic.

---

## Common Patterns

### Status/Info Default Command

Default command shows current state:
- Package status
- Service health
- Configuration summary

Subcommands perform actions:
- Install/uninstall
- Start/stop
- Configure

### Progressive Arguments

Start with sensible defaults, allow overrides:
- Required parameters: Only what's absolutely necessary
- Optional parameters: Provide defaults for common cases
- Switches: Enable advanced behavior

### Validation Before Action

Order of operations:
1. Validate all inputs
2. Check prerequisites (files exist, permissions, etc.)
3. Perform action
4. Provide feedback

### Confirmation for Destructive Actions

Use `-Confirm` pattern for dangerous operations:
- Deletions
- Overwrites
- Irreversible changes

### Idempotent Operations

Design commands to be safely re-run:
- Check if action already done
- Skip if no work needed
- Report what changed vs what was already correct

---

## Best Practices Summary

### Do

✅ Include comprehensive comment-based help
✅ Validate inputs early
✅ Provide clear error messages
✅ Use PowerShell native features (parameter binding, validation)
✅ Follow naming conventions
✅ Test both success and failure paths
✅ Document dependencies in metadata
✅ Use default commands for common operations

### Don't

❌ Silently fail or ignore errors
❌ Use global variables (scope conflicts)
❌ Hardcode paths (use `$PSScriptRoot`)
❌ Create overly complex logic in single file
❌ Forget to document parameters
❌ Override reserved names (`help`, `version`, `info`)
❌ Use `-CommandPath` parameter in non-dispatcher functions

---

## Troubleshooting

### Module Not Found

**Check**:
- File in correct directory (`.box/modules/` or `modules/`)
- Filename matches command name exactly
- File has `.ps1` extension

### Subcommand Not Recognized

**Check**:
- File in command directory (e.g., `pkg/install.ps1`)
- Filename matches subcommand name
- Not in subdirectory (only root-level `.ps1` discovered)

### Arguments Not Binding

**Check**:
- Parameter names match (case-insensitive)
- Parameter types compatible with passed values
- Required parameters declared correctly
- Use `[Parameter(ValueFromRemainingArguments)]` for variable args

### Help Not Showing

**Check**:
- Comment-based help at top of file
- `.SYNOPSIS` included
- No syntax errors in help block
- Help block before `param()` block

---

## Next Steps

- **Metadata Reference**: See [Metadata Schema Reference](./modules-metadata.md)
- **Examples**: Check `MODULES2.md` for working examples
- **Core Development**: See [Embedded Module Guide](./modules-embedded.md)

---

**Happy coding!** 🚀
