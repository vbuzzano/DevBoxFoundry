# Embedded Module Guide

**Audience**: Boxing Core Contributors
**Purpose**: Guidelines for developing embedded (built-in) modules

---

## What Are Embedded Modules?

Embedded modules are built-in commands compiled directly into `boxer.ps1` and `box.ps1` executables. They provide core functionality shipped with Boxing.

### Characteristics

**Source location**: `DevBoxFoundry/modules/{mode}/`
**Distribution**: Compiled into single-file executables
**Priority**: Lower than external modules (users can override)
**Discovery**: Function name pattern matching
**Help**: Comment-based help in source

---

## Module Modes

### Boxer Modules

**Location**: `DevBoxFoundry/modules/boxer/`

**Purpose**: Global system operations
- Installation and updates
- Configuration management
- System-wide settings

**Examples**:
- `install.ps1` → `boxer install`
- `update.ps1` → `boxer update`
- `config.ps1` → `boxer config`

### Box Modules

**Location**: `DevBoxFoundry/modules/box/`

**Purpose**: Project-level operations
- Package management
- Environment handling
- Project commands

**Examples**:
- `env.ps1` → `box env`
- `load.ps1` → `box load`
- `pkg/install.ps1` → `box pkg install`

### Shared Utilities

**Location**: `DevBoxFoundry/modules/shared/`

**Purpose**: Code reuse between boxer and box
- NOT CLI commands
- Compiled as private functions
- Available in both executables

**Examples**:
- `helpers/validation.ps1`
- `helpers/download.ps1`
- `helpers/ui.ps1`

---

## Development Workflow

### 1. Create Source File

Write module as standalone PowerShell script in appropriate directory.

**Location rules**:
- Boxer-only: `modules/boxer/{command}.ps1`
- Box-only: `modules/box/{command}.ps1`
- Subcommands: `modules/{mode}/{command}/{subcommand}.ps1`

### 2. Write Comment-Based Help

Include comprehensive help at top of script.

**Required sections**:
- `.SYNOPSIS` - One-line description
- `.DESCRIPTION` - Detailed explanation
- `.PARAMETER` - Document each parameter
- `.EXAMPLE` - At least one usage example

**Optional but recommended**:
- `.NOTES` - Additional information
- `.LINK` - Related commands or documentation

### 3. Define Parameters

Use PowerShell parameter block with validation.

**Best practices**:
- Mark required parameters
- Provide defaults for optional parameters
- Use validation attributes
- Document parameter purpose

### 4. Implement Logic

Write command implementation.

**Guidelines**:
- Use core functions from `core/` directory
- Call shared utilities from `modules/shared/`
- Handle errors gracefully
- Provide informative output
- Follow project coding standards

### 5. Test Source Script

Test before building to catch issues early.

**Manual testing**:
- Run script directly with `&` operator
- Test various parameter combinations
- Verify help displays correctly
- Check error handling

### 6. Build Executable

Run build script to compile into monolithic file.

**Commands**:
- `.\scripts\build-boxer.ps1` - Build boxer.ps1
- `.\scripts\build-box.ps1` - Build box.ps1

### 7. Test Built Executable

Verify compiled version works correctly.

**Testing**:
- Run command through CLI: `boxer {command}` or `box {command}`
- Test help: `boxer help {command}`
- Verify function name generated correctly
- Check integration with other commands

---

## Build Process Details

### Source Transformation

Build script transforms each source file into function.

**Input** (source file):
```
Comment-based help
param(...)
Implementation
```

**Output** (in built file):
```
function Invoke-{Mode}-{Command} {
    Comment-based help
    param(...)
    Implementation
}
```

### Function Naming Convention

**Pattern**: `Invoke-{Mode}-{Command}`

**Examples**:
- `modules/boxer/install.ps1` → `Invoke-Boxer-Install`
- `modules/box/env.ps1` → `Invoke-Box-Env`
- `modules/box/pkg/install.ps1` → `Invoke-Box-Pkg-Install`

**Subcommands**: Hierarchical naming
- Directory structure: `box/pkg/install.ps1`
- Function name: `Invoke-Box-Pkg-Install`

### Compilation Steps

**Build script performs**:
1. Load all source modules from `modules/{mode}/`
2. Transform each into function with naming pattern
3. Preserve comment-based help and parameters
4. Include shared utilities from `modules/shared/`
5. Include core functions from `core/`
6. Set `$script:IsEmbedded = $true` flag
7. Append bootstrapper from `boxing.ps1`
8. Write monolithic executable

### Discovery at Runtime

**How system finds embedded commands**:
1. Scan for functions matching `Invoke-{Mode}-*` pattern
2. Extract command name from function name
3. Register command in routing table
4. Extract help via `Get-Help {FunctionName}`

---

## Code Organization

### Single-Level Commands

**Structure**: One file per command

**Example**: `modules/boxer/install.ps1`

**Becomes**: `boxer install` command

### Multi-Level Commands (Subcommands)

**Structure**: Directory with subcommand files

**Example**:
```
modules/box/pkg/
├── install.ps1
├── uninstall.ps1
└── list.ps1
```

**Becomes**:
- `box pkg install`
- `box pkg uninstall`
- `box pkg list`

### Default Commands

**Pattern**: File matching directory name

**Example**:
```
modules/box/pkg/
├── pkg.ps1      ← Default
├── install.ps1
└── list.ps1
```

**Behavior**:
- `box pkg` → Executes `pkg.ps1`
- `box pkg install` → Executes `install.ps1`

---

## Dependencies

### Core Functions

**Location**: `DevBoxFoundry/core/`

**Available to all modules**:
- `common.ps1` - Utility functions
- `ui.ps1` - User interface helpers
- `config.ps1` - Configuration management
- `download.ps1` - Download utilities

**Usage**: Just call functions directly (already loaded)

### Shared Utilities

**Location**: `DevBoxFoundry/modules/shared/`

**Purpose**: Reusable logic for modules

**Behavior**: Compiled as private functions (not CLI commands)

**Usage**: Call functions directly (available in scope)

### External Dependencies

**PowerShell modules**: Can use standard modules

**External executables**: Document requirements in help

**Validation**: Check dependencies in code, fail gracefully if missing

---

## Best Practices

### Help Documentation

**Always include**:
- Clear synopsis (will appear in command listings)
- Detailed description explaining purpose
- Every parameter documented
- Realistic examples showing common usage

**Quality matters**: Help is user's first resource

### Parameter Design

**Required vs Optional**:
- Minimize required parameters
- Provide sensible defaults
- Use switches for boolean options

**Validation**:
- Validate early (in parameter attributes)
- Fail fast with clear messages
- Use PowerShell built-in validators when possible

### Error Handling

**User-friendly errors**:
- Explain what went wrong
- Suggest how to fix
- Avoid technical jargon when possible

**Exit codes**:
- 0 for success
- Non-zero for failures
- Consistent across commands

### Output Standards

**Informative feedback**:
- Confirm actions taken
- Show progress for long operations
- Use `Write-Host` for user messages
- Use `Write-Verbose` for debug info

**Consistent formatting**:
- Follow project style guidelines
- Use colors appropriately
- Structure output clearly

### Performance

**Fast startup**:
- Avoid expensive initialization
- Lazy-load when possible
- Cache results appropriately

**Efficient execution**:
- Avoid unnecessary loops
- Use PowerShell pipeline efficiently
- Clean up resources

---

## Testing Strategy

### Unit Testing

**Source script level**:
- Test logic directly
- Mock dependencies
- Verify error handling

### Integration Testing

**Built executable level**:
- Test command execution
- Verify help system
- Check argument binding
- Validate output format

### Regression Testing

**Before releases**:
- Test all existing commands
- Verify backward compatibility
- Check for breaking changes

---

## Version Control

### Commit Guidelines

**One module per commit**: Makes changes trackable

**Clear messages**: Explain what and why

**Reference issues**: Link to relevant issues/tasks

### Code Review

**Before merging**:
- Help documentation complete
- Code follows standards
- Tests pass
- No breaking changes (or documented)

---

## Release Process

### Pre-release Checklist

- [ ] All modules documented
- [ ] Help text reviewed
- [ ] Examples tested
- [ ] Breaking changes documented
- [ ] Build succeeds without errors
- [ ] Integration tests pass

### Build for Release

**Commands**:
```
# Build both executables
.\scripts\build-boxer.ps1
.\scripts\build-box.ps1

# Test built versions
.\boxer.ps1 help
.\box.ps1 help
```

### Distribution

**Output files**:
- `boxer.ps1` - Global CLI
- `box.ps1` - Project template

**Packaging**: Via release scripts in `scripts/release.ps1`

---

## Migration from External to Embedded

### When to Embed

**Consider embedding when**:
- Command needed by all users
- Part of core functionality
- Mature and stable
- Well-tested and documented

**Keep external when**:
- Experimental or in development
- User-specific or optional
- Frequently changing
- Not universally needed

### Migration Steps

1. Move source to `modules/{mode}/`
2. Ensure comment-based help complete
3. Remove any external module assumptions
4. Add to build process
5. Test built version
6. Document in release notes
7. Update user documentation

---

## Troubleshooting

### Function Not Found

**Check**:
- File in correct `modules/{mode}/` directory
- Build script ran successfully
- Function naming matches pattern
- No syntax errors in source

### Help Not Displaying

**Check**:
- Comment-based help at top of file (before param block)
- All help keywords spelled correctly
- No syntax errors in help comments
- `Get-Help Invoke-{Mode}-{Command}` works on built function

### Parameters Not Binding

**Check**:
- Parameter block syntax correct
- Types compatible with input
- No naming conflicts
- Attribute syntax correct

### Build Failures

**Check**:
- All source files valid PowerShell
- No unmatched braces or quotes
- Functions defined correctly
- Dependencies available

---

## Example: Complete Embedded Module

**File**: `modules/boxer/update.ps1`

**Principles demonstrated**:
- Complete comment-based help
- Parameter validation
- Error handling
- User feedback
- Exit codes

**After build becomes**: `Invoke-Boxer-Update` function in `boxer.ps1`

**CLI usage**: `boxer update` or `boxer update -Version 2.1.0`

---

## Next Steps

- **Module Development**: See [Module Development Guide](./modules-development.md)
- **System Overview**: See [Module System Overview](./modules-overview.md)
- **Examples**: Check `MODULES2.md` for complete examples

---

**Contributing**: Follow project contribution guidelines in repository
