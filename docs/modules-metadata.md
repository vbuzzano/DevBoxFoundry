# Metadata Schema Reference

**Audience**: Advanced Module Authors
**Purpose**: Complete metadata.psd1 field reference

---

## Overview

Metadata files (`metadata.psd1`) provide declarative module configuration. Written in PowerShell Data (PSD1) format for easy parsing and validation.

---

## Root Level Schema

### Required Fields

#### ModuleName
- **Type**: String
- **Purpose**: Unique module identifier
- **Format**: Lowercase, alphanumeric, hyphens allowed
- **Example**: `'auth'`, `'docker-manager'`

#### Version
- **Type**: String (Semantic version)
- **Purpose**: Module version for tracking and compatibility
- **Format**: `Major.Minor.Patch` (e.g., `'1.2.3'`)
- **Usage**: Displayed in `box info`, `box version {module}`

#### Commands
- **Type**: Hashtable
- **Purpose**: Command registration and routing
- **Requirement**: At least one command required
- **See**: Command Definition section below

### Optional Fields

#### Description
- **Type**: String
- **Purpose**: Module description for documentation
- **Usage**: Shown in help listings
- **Example**: `'Authentication and credential management'`

#### Author
- **Type**: String
- **Purpose**: Module author attribution
- **Example**: `'Boxing Team'`

#### Copyright
- **Type**: String
- **Purpose**: Copyright notice
- **Example**: `'Copyright (c) 2026 Boxing Team'`

#### ProjectUri
- **Type**: String (URI)
- **Purpose**: Link to project homepage or repository
- **Example**: `'https://github.com/boxing/auth-module'`

#### LicenseUri
- **Type**: String (URI)
- **Purpose**: Link to license file
- **Example**: `'https://github.com/boxing/auth-module/blob/main/LICENSE'`

#### Tags
- **Type**: Array of strings
- **Purpose**: Searchable keywords for module discovery
- **Example**: `@('auth', 'security', 'credentials')`

#### PrivateFunctions
- **Type**: Array of strings
- **Purpose**: Functions to exclude from command registration
- **Usage**: Helper functions not meant to be CLI commands
- **Example**: `@('Validate-Credentials', 'Get-SecureToken')`

#### Hook-ModuleLoad
- **Type**: String (function name)
- **Purpose**: Function called after module loads
- **Usage**: Initialize state, connect to services, validate environment
- **Contract**: No parameters, no return value expected

#### Hook-ModuleUnload
- **Type**: String (function name)
- **Purpose**: Function called before module unloads
- **Usage**: Cleanup resources, close connections, save state
- **Contract**: No parameters, no return value expected

---

## Command Definition Schema

Commands hashtable maps command names to configurations.

### Command Key

- **Type**: String
- **Format**: Lowercase, no spaces, alphanumeric
- **Purpose**: CLI command name as user types it
- **Example**: `'login'`, `'deploy'`, `'container'`

### Handler (Choice 1 of 3)

#### Simple Script Path
- **Type**: String (relative path)
- **Purpose**: Path to script file from module directory
- **Example**: `Handler = 'login.ps1'`
- **Execution**: `& "$ModuleDir/login.ps1" @args`

#### Function Name
- **Type**: String (function name)
- **Purpose**: Function name to call
- **Example**: `Handler = 'Invoke-LoginProcess'`
- **Requirement**: Function must exist in module files
- **Execution**: `& Invoke-LoginProcess @args`

#### File::Function Syntax
- **Type**: String (path::function)
- **Purpose**: Specific function in specific file
- **Format**: `'relative/path/file.ps1::FunctionName'`
- **Example**: `Handler = 'helpers/auth.ps1::Process-Login'`
- **Execution**: Dot-sources file, calls function

### Dispatcher (Choice 2 of 3)

- **Type**: String (function name)
- **Purpose**: Custom routing function for all subcommands
- **Contract**: Must accept `-CommandPath [string[]]` parameter
- **Usage**: When dynamic routing or complex logic needed
- **Example**: `Dispatcher = 'Invoke-Docker-Dispatcher'`
- **Incompatible with**: Subcommands field (dispatcher handles routing)

### No Handler/Dispatcher (Choice 3 of 3)

- **Implicit behavior**: Command requires subcommand
- **When called**: Shows help (lists available subcommands)
- **Requirement**: Subcommands must be defined
- **Use case**: Pure multi-command modules

### Subcommands (Optional)

- **Type**: Hashtable
- **Purpose**: Define subcommand routing
- **Incompatible with**: Dispatcher
- **Structure**: Nested command definitions (same schema as root commands)

**Each subcommand requires**:
- `Handler` - How to execute (same types as command handler)
- `Synopsis` - Brief description for help listings

**Each subcommand optional**:
- `Description` - Detailed help text
- `Hidden` - Hide from help listings

### Synopsis (Required)

- **Type**: String
- **Purpose**: Brief one-line description
- **Usage**: Shown in `box help` command listings
- **Length**: Keep under 60 characters for clean formatting
- **Example**: `'Authenticate user with credentials'`

### Description (Optional)

- **Type**: String
- **Purpose**: Detailed help text
- **Usage**: Shown in `box help {command}` detailed view
- **Fallback**: If not provided, system uses `Get-Help` on handler
- **Example**: `'Authenticate user with credentials and create session token. Supports multiple authentication providers.'`

### Hidden (Optional)

- **Type**: Boolean
- **Purpose**: Hide command from help listings
- **Default**: `$false`
- **Use case**: Internal commands, deprecated commands, experimental features
- **Note**: Command still executable, just not listed

---

## Handler Resolution Logic

### Script Path Resolution

**Pattern**: `Handler = 'script.ps1'`

1. Resolve path: `$ModuleDir/script.ps1`
2. Verify file exists
3. Execute: `& $resolvedPath @remainingArgs`

### Function Resolution

**Pattern**: `Handler = 'FunctionName'`

1. Check if function exists in current scope
2. If not found, scan all module `.ps1` files for function definition
3. Dot-source file containing function
4. Execute: `& FunctionName @remainingArgs`

### File::Function Resolution

**Pattern**: `Handler = 'path/file.ps1::FunctionName'`

1. Split on `::`
2. Resolve file path: `$ModuleDir/path/file.ps1`
3. Dot-source file
4. Execute: `& FunctionName @remainingArgs`

### Dispatcher Resolution

**Pattern**: `Dispatcher = 'DispatcherFunction'`

1. Resolve function (same as Function Resolution above)
2. Build command path array from invocation
3. Execute: `& DispatcherFunction -CommandPath @(...) @remainingArgs`

---

## Default Command Logic

Determines what happens when command called without subcommand.

### Four Scenarios

#### 1. Handler Only (No Subcommands)
**Configuration**: Handler specified, no Subcommands
**Behavior**: Always executes handler
**Use case**: Simple single-purpose command

#### 2. Handler + Subcommands
**Configuration**: Both Handler and Subcommands specified
**Behavior**:
- Without subcommand → Executes handler (default action)
- With subcommand → Executes subcommand handler
**Use case**: Command with common default operation plus specific actions

#### 3. Subcommands Only (No Handler)
**Configuration**: Subcommands specified, no Handler
**Behavior**: Always shows help (lists subcommands)
**Use case**: Pure multi-command module requiring explicit choice

#### 4. Dispatcher
**Configuration**: Dispatcher specified
**Behavior**: Dispatcher called with empty or populated CommandPath
**Use case**: Custom routing logic

---

## Validation Rules

### At Module Load

**Required field validation**:
- ModuleName present and valid
- Version present and valid semantic version format
- Commands present and non-empty
- Each command has valid configuration

**Handler validation**:
- At least one of: Handler, Dispatcher, or Subcommands
- Handler and Dispatcher mutually exclusive
- Dispatcher and Subcommands mutually exclusive

**File validation**:
- Script paths resolve to existing files
- Functions exist in module scope

### Error Behavior

**Invalid metadata**: Module load fails, warning logged, other modules continue loading

**Missing handler file**: Command registration skipped, error logged, other commands in module still registered

**Invalid function**: Runtime error when command invoked, clear message to user

---

## Reserved Names

### Parameter Names

**Reserved for dispatcher only**:
- `-CommandPath` - System-provided command path array

**Recommendation**: Avoid these in regular handlers to prevent confusion

### Command Names

**System commands** (can be overridden but not recommended):
- `help` - Help system
- `version` - Version display
- `info` - Module listing

### File Names

**Special meaning**:
- `metadata.psd1` - Module metadata
- `{module}.ps1` - Default command (must match directory name)
- `help.ps1` - Custom help handler (optional)

---

## Hooks Contract

### Hook-ModuleLoad

**Called**: After metadata loaded, all files sourced, before commands registered

**Purpose**:
- Validate environment prerequisites
- Initialize module state
- Connect to external services
- Setup background jobs

**Signature**: No parameters

**Error handling**: If throws, module load fails

### Hook-ModuleUnload

**Called**: When module unloaded or box/boxer exits

**Purpose**:
- Close connections
- Cleanup temporary resources
- Save state if needed
- Stop background jobs

**Signature**: No parameters

**Error handling**: Logged but doesn't prevent unload

---

## Complete Example

Annotated example showing all major features:

```
Root level: Identity and lifecycle
├── ModuleName, Version (required)
├── Description, Author, etc. (optional metadata)
└── Hooks (initialization/cleanup)

Commands level: CLI registration
├── Command without subcommands
│   ├── Handler (direct execution)
│   └── Synopsis, Description (help)
│
├── Command with default + subcommands
│   ├── Handler (default action)
│   ├── Synopsis, Description (command help)
│   └── Subcommands
│       ├── Subcommand 1 (Handler, Synopsis)
│       └── Subcommand 2 (Handler, Synopsis)
│
├── Command with subcommands only
│   ├── No Handler (shows help by default)
│   ├── Synopsis (command help)
│   └── Subcommands (required explicit choice)
│
└── Command with dispatcher
    ├── Dispatcher (custom routing)
    └── Synopsis (help)

PrivateFunctions: Hidden helpers (not CLI commands)
```

---

## Migration from Simple Modules

### When to Add Metadata

**Consider metadata when**:
- Need multi-level subcommands
- Want declarative routing
- Module has dependencies
- Need lifecycle hooks
- Want versioning
- Complex validation required

**Stick with simple when**:
- Single command or flat subcommands
- No special dependencies
- Auto-discovery works fine
- Metadata feels like overkill

### Migration Steps

1. Create `metadata.psd1` in module directory
2. Define ModuleName, Version, Commands
3. Map existing files to handlers in Commands
4. Add Synopsis for help
5. Test routing still works
6. Add advanced features as needed (hooks, private functions, etc.)

---

## Troubleshooting

### Module Not Loading

**Check**:
- PSD1 syntax valid (matching braces, quotes, commas)
- Required fields present (ModuleName, Version, Commands)
- File named exactly `metadata.psd1`

### Handler Not Found

**Check**:
- Handler path correct relative to module directory
- File exists at specified path
- Function name spelled correctly (case-sensitive)
- File::Function syntax uses `::` separator

### Subcommands Not Working

**Check**:
- Not using Dispatcher (incompatible)
- Each subcommand has Handler
- Subcommand names match user invocation

### Dispatcher Not Receiving CommandPath

**Check**:
- Function has `-CommandPath` parameter
- Parameter type is `[string[]]`
- Using `ValueFromRemainingArguments` for other args

---

## Next Steps

- **Examples**: See complete examples in `MODULES2.md`
- **Development**: See [Module Development Guide](./modules-development.md)
- **Core Concepts**: See [Module System Overview](./modules-overview.md)

---

**Reference**: Full technical specification in `MODULES2.md`
