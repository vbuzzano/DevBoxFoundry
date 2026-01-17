# Module System v2 - Simplified Architecture

**Status**: Final specification
**Date**: 2026-01-14
**Replaces**: MODULES.md (legacy function-based approach)

---

## Philosophy

The Boxing module system v2 follows these principles:

1. **Simple by default**: External modules are just PowerShell scripts routed by the CLI
2. **Embedded modules use functions**: Built-in modules compiled into boxer.ps1/box.ps1 use `Invoke-{Mode}-{Command}` pattern
3. **No mandatory functions for external modules**: User scripts execute directly unless complex routing is needed
4. **Metadata from comments**: Help extracted from standard PowerShell comment-based help using `Get-Help`
5. **Complex when needed**: Metadata files enable advanced dispatch for multi-level commands
6. **Auto-discovery**: Everything discovered dynamically at runtime - no hardcoded registries
7. **Priority system**: External modules override embedded modules

---

## Two Phases: Development vs Runtime

### Phase 1: DevBoxFoundry Project Structure (Development)

During development of Boxing itself:

```
DevBoxFoundry/
├── core/                      # Shared helpers (UI, download, config)
│   ├── common.ps1
│   ├── ui.ps1
│   ├── download.ps1
│   └── config.ps1
│
├── modules/
│   ├── boxer/                 # Boxer-only commands
│   │   ├── install.ps1
│   │   ├── update.ps1
│   │   └── config.ps1
│   │
│   ├── box/                   # Box-only commands
│   │   ├── pkg/
│   │   │   ├── install.ps1
│   │   │   ├── list.ps1
│   │   │   └── uninstall.ps1
│   │   ├── env.ps1
│   │   ├── load.ps1
│   │   └── status.ps1
│   │
│   └── shared/                # Reusable helpers (NOT CLI commands)
│       └── helpers/
│           ├── validate-package.ps1
│           └── format-output.ps1
│
├── boxing.ps1                 # Common bootstrapper
├── scripts/
│   ├── build-boxer.ps1        # Compiles final boxer.ps1
│   └── build-box.ps1          # Compiles box.ps1 template
```

**Important**: `modules/shared/` contains **utility functions only**, not CLI commands. Used for code reuse during build.

### Phase 2: After Build (Distribution)

#### A) Boxer Installation (Global)

```
PowerShell/Boxing/
├── boxer.ps1                  # Monolithic file with embedded modules
└── modules/                   # (Optional) User custom modules
    └── mycommand.ps1
```

**boxer.ps1** contains:
- Core functions (from `core/*.ps1`)
- Shared helpers (from `modules/shared/*.ps1`)
- Boxer commands as functions: `Invoke-Boxer-Install`, `Invoke-Boxer-Update`, etc.
- Bootstrapper from `boxing.ps1`

#### B) Box in Workspace (Project)

```
MonProjet/
├── .box/
│   ├── box.ps1                # Monolithic file with embedded modules
│   └── modules/               # (Optional) User custom modules
│       └── deploy.ps1
│
└── modules/                   # (Optional) Project-specific modules
    └── build.ps1
```

**.box/box.ps1** contains:
- Core functions (from `core/*.ps1`)
- Shared helpers (from `modules/shared/*.ps1`)
- Box commands as functions: `Invoke-Box-Pkg-Install`, `Invoke-Box-Env`, etc.
- Bootstrapper from `boxing.ps1`

---

## Module Types

### 1. Embedded Module (Compiled into boxer.ps1/box.ps1)

**Source Location**: `DevBoxFoundry/modules/{mode}/{command}.ps1`

**Build Output**: Function in boxer.ps1 or box.ps1

```powershell
# Source: modules/boxer/update.ps1
<#
.SYNOPSIS
Update boxer to latest version

.PARAMETER Version
Specific version to install

.EXAMPLE
boxer update
.EXAMPLE
boxer update -Version 2.1.0
#>
param([string]$Version)

# Update logic here
Write-Host "Updating boxer..."
```

**After build** → Compiled as function in `boxer.ps1`:

```powershell
function Invoke-Boxer-Update {
    <#
    .SYNOPSIS
    Update boxer to latest version

    .PARAMETER Version
    Specific version to install

    .EXAMPLE
    boxer update
    .EXAMPLE
    boxer update -Version 2.1.0
    #>
    param([string]$Version)

    # Update logic here
    Write-Host "Updating boxer..."
}
```

**Behavior**:
- CLI: `boxer update` or `box command`
- Discovery: Function scan `Invoke-{Mode}-*` at runtime
- Execution: Function call `& Invoke-Boxer-Update @args`
- Help: Extracted using `Get-Help Invoke-Boxer-Update`
- **Always requires `Invoke-{Mode}-{Command}` function pattern**

---

### 2. External Module (Single File)

**Location**:
- Boxer: `PowerShell/Boxing/modules/{command}.ps1`
- Box: `MonProjet/.box/modules/{command}.ps1` or `MonProjet/modules/{command}.ps1`

**Structure**:
```powershell
<#
.SYNOPSIS
Brief description of what this command does

.DESCRIPTION
Detailed explanation of the command behavior

.PARAMETER param1
Description of first parameter

.PARAMETER param2
Description of second parameter

.EXAMPLE
box mycommand arg1 arg2
Description of this example

.EXAMPLE
box mycommand --flag
Another example

.NOTES
Additional information, author, version, etc.
#>

param(
    [string]$Param1,
    [string]$Param2
)

# Your actual command logic here
Write-Host "Hello from $Param1"
```

**Behavior**:
- CLI: `box mycommand arg1 arg2`
- Execution: Script executed directly `& "path/to/mycommand.ps1" @args`
- Help: Extracted using PowerShell's `Get-Help` on the script file
- **No `Invoke-Box-*` function required** (this is the v2 simplification)
- **Higher priority than embedded modules**

---

### 3. External Module (Directory with Subcommands)

**Location**:
- Boxer: `PowerShell/Boxing/modules/{command}/`
- Box: `MonProjet/.box/modules/{command}/` or `MonProjet/modules/{command}/`

**Structure**:
```
modules/box/pkg/
├── install.ps1
├── uninstall.ps1
├── list.ps1
└── update.ps1
```

**Each subcommand file** (e.g., `install.ps1`):
```powershell
<#
.SYNOPSIS
Install a package into the current box

.DESCRIPTION
Downloads and installs the specified package with optional version pinning

.PARAMETER PackageName
Name of the package to install

.PARAMETER Version
Specific version to install (optional)

.EXAMPLE
box pkg install vscode
Install latest version of vscode

.EXAMPLE
box pkg install vscode -Version 1.85.0
Install specific version
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$PackageName,

    [string]$Version
)

# Installation logic here
Write-Host "Installing $PackageName..."
```

**Behavior**:
- CLI: `box pkg install vscode`
- Discovery: System finds `modules/box/pkg/install.ps1`
- Execution: Script executes directly with remaining args
- Help: `box pkg install --help` shows comment-based help from `install.ps1`

**Auto-routing**:
- `box pkg install` → Executes `install.ps1`
- `box pkg unknown` → Error: "Unknown subcommand 'unknown'. Available: install, uninstall, list, update"
- **Higher priority than embedded modules**

**Default Command Convention**:

When calling module without subcommand: `box pkg`

1. **If `pkg.ps1` exists** in module directory → Execute as default command
   ```
   modules/pkg/
   ├── pkg.ps1          ← Default command (executed when 'box pkg')
   ├── install.ps1
   ├── uninstall.ps1
   └── list.ps1
   ```
   - `box pkg` → Executes `pkg.ps1` (e.g., shows pkg status, version, config)
   - `box pkg install` → Executes `install.ps1`

2. **If `pkg.ps1` does NOT exist** → Show help
   ```
   modules/pkg/
   ├── install.ps1
   ├── uninstall.ps1
   └── list.ps1
   ```
   - `box pkg` → Automatically shows `box help pkg` (lists available subcommands)
   - Forces explicit subcommand selection

**Naming Rule**: Default command file must match module directory name (`pkg/pkg.ps1`, `docker/docker.ps1`, etc.)

---

### 4. Complex Module (With Metadata)

For modules needing custom dispatch logic, validation, dependencies, or advanced routing.

**Location**: Same as external modules (user directories)

#### Metadata File (`metadata.psd1`)

**When to use**: Modules with complex dependencies, custom dispatch logic, strict validation requirements

**Advantages**:
- Declarative and easy to parse
- Can be loaded without executing code
- Better for security scanning
- Clear separation of metadata and logic

**Structure**:
```
.box/modules/auth/
├── metadata.psd1
├── login.ps1
├── logout.ps1
├── helpers/
│   └── token-manager.ps1
└── validators/
    └── credential-validator.ps1
```

**metadata.psd1**:
```powershell
@{
    # Module identity
    ModuleName = 'auth'
    Version = '2.1.0'
    Description = 'Authentication and credential management'
    Author = 'Boxing Team'

    # Command registration
    Commands = @{
        # Simple command mapping
        'login' = @{
            Handler = 'login.ps1'
            Synopsis = 'Authenticate user'  # For 'box help' listing
            Description = 'Authenticate user with credentials and create session token'  # For 'box help auth login'
        }

        # Command with subcommands
        'token' = @{
            Synopsis = 'Manage authentication tokens'
            Description = 'Refresh, revoke, and manage session tokens'
            Subcommands = @{
                'refresh' = @{
                    Handler = 'helpers/token-manager.ps1::Refresh-Token'
                    Synopsis = 'Refresh auth token'
                    Description = 'Extend current session by refreshing the authentication token'
                }
                'revoke' = @{
                    Handler = 'helpers/token-manager.ps1::Revoke-Token'
                    Synopsis = 'Revoke auth token'
                    Description = 'Invalidate current authentication token and end session'
                }
            }
        }

        # Command with handler
        'logout' = @{
            Handler = 'logout.ps1'
            Synopsis = 'End session'
            Description = 'Log out current user and clear session data'
        }
    }

    # Private functions (not exposed as commands)
    PrivateFunctions = @(
        'Validate-Credentials',
        'Store-SecureToken'
    )

    # Hooks (optional)
    Hook-ModuleLoad = 'Initialize-AuthModule'
    Hook-ModuleUnload = 'Cleanup-AuthModule'
}
```

---

## Metadata Schema (Complete)

### Root Level Keys

```powershell
@{
    # === IDENTITY (Required) ===
    ModuleName = 'string'          # Module identifier
    Version = 'semver'             # Semantic version
    Description = 'string'         # Module description

    # === IDENTITY (Optional) ===
    Author = 'string'
    Copyright = 'string'
    ProjectUri = 'uri'
    LicenseUri = 'uri'
    Tags = @('tag1', 'tag2')

    # === COMMANDS (Required) ===
    Commands = @{
        # See "Command Definition" below
    }

    # === VISIBILITY ===
    PrivateFunctions = @('Func1', 'Func2')  # Not exposed as commands

    # === LIFECYCLE HOOKS ===
    Hook-ModuleLoad = 'FunctionName'      # Called after module loads
    Hook-ModuleUnload = 'FunctionName'    # Called before module unloads
}
```

### Command Definition

```powershell
Commands = @{
    'commandname' = @{
        # === HANDLER (Optional with Subcommands, Required without) ===
        Handler = 'script.ps1'                    # Relative path to script
        Handler = 'Invoke-Function-Name'          # Function name
        Handler = 'dir/script.ps1::FunctionName'  # Specific function in file

        # OR for custom dispatch
        Dispatcher = 'Get-CustomDispatcher'       # Function handling all subcommands + help
                                                  # Must accept -CommandPath parameter

        # === SUBCOMMANDS (Optional, not used with Dispatcher) ===
        Subcommands = @{
            'sub1' = @{
                Handler = '...'                      # Required for each subcommand
                Synopsis = 'Short description'       # For listing
                Description = 'Detailed help text'   # For 'box help command sub1'
            }
            'sub2' = @{ Handler = '...', Synopsis = '...' }
        }

        # === HELP (Required) ===
        Synopsis = 'Brief description'             # For 'box help' listing
        Description = 'Detailed help text'         # For 'box help commandname'

        # === METADATA (Optional) ===
        Hidden = $false                            # Hide from help listing
    }
}
```

**Default Command Logic**:
- **Handler + Subcommands**: `box command` executes Handler (default), `box command sub1` executes subcommand
- **Subcommands only (no Handler)**: `box command` shows help listing subcommands
- **Handler only (no Subcommands)**: `box command` executes Handler
- **Dispatcher**: Handles all routing (default + subcommands + help)

### Required vs Optional Fields

**Minimal Valid Metadata** (absolute minimum):
```powershell
@{
    ModuleName = 'mymodule'                    # REQUIRED
    Version = '1.0.0'                          # REQUIRED
    Commands = @{                              # REQUIRED (at least one)
        'start' = @{
            Handler = 'start.ps1'              # REQUIRED (Handler OR Dispatcher)
            Synopsis = 'Start service'         # REQUIRED
        }
    }
}
```

**Root Level - Required vs Optional**:
```powershell
@{
    # REQUIRED
    ModuleName = 'string'          # Module identifier
    Version = 'semver'             # Module version
    Commands = @{ ... }            # At least one command

    # OPTIONAL
    Description = 'string'         # Module description
    Author = 'string'
    Copyright = 'string'
    ProjectUri = 'uri'
    LicenseUri = 'uri'
    Tags = @('tag1', 'tag2')
    PrivateFunctions = @('Func1')
    Hook-ModuleLoad = 'FunctionName'
    Hook-ModuleUnload = 'FunctionName'
}
```

**Command Level - Required vs Optional**:
```powershell
'commandname' = @{
    # REQUIRED (choose one, except if only Subcommands)
    Handler = 'script.ps1'         # Script path, function name, or path::function
    # OR
    Dispatcher = 'FunctionName'    # Custom dispatcher function
    # OR (implicit)
    # No Handler/Dispatcher but Subcommands defined → defaults to help

    # REQUIRED
    Synopsis = 'Brief description' # For 'box help' listing

    # OPTIONAL
    Description = 'Detailed text'  # For 'box help command' (falls back to Get-Help)
    Subcommands = @{ ... }         # Subcommands (not compatible with Dispatcher)
    Hidden = $false                # Hide from help listing
}
```

**Handler/Dispatcher Rules**:
1. **Handler only**: Command executes handler
2. **Handler + Subcommands**: Command executes handler (default), subcommands execute their handlers
3. **Subcommands only**: Command shows help, subcommands execute their handlers
4. **Dispatcher**: Dispatcher handles everything (command + subcommands + help)

**Handler Resolution Rules**:

1. **Simple script path**: `Handler = 'start.ps1'`
   - System looks for `start.ps1` in module directory
   - Executes script directly: `& "$ModuleDir/start.ps1" @args`

2. **Function name**: `Handler = 'Invoke-MyCommand'`
   - System looks for function in ALL `.ps1` files in module directory
   - Dot-sources files containing the function
   - Calls function: `& Invoke-MyCommand @args`

3. **Path::Function**: `Handler = 'helpers/manager.ps1::Process-Data'`
   - System dot-sources specific file: `. "$ModuleDir/helpers/manager.ps1"`
   - Calls function: `& Process-Data @args`

4. **Dispatcher**: `Dispatcher = 'My-Dispatcher'`
   - System looks for function in ALL `.ps1` files
   - Calls with subcommand: `& My-Dispatcher $subcommand @args`
   - Dispatcher handles ALL routing including help

**Note**: With metadata, system **dot-sources all `.ps1` files** in module directory during load, making all functions available.

---

## Hooks System

### Module Hooks

Module hooks are called during module lifecycle:

```powershell
# In metadata.psd1
@{
    Hook-ModuleLoad = 'Initialize-MyModule'      # Called after module loads
    Hook-ModuleUnload = 'Cleanup-MyModule'       # Called before module unloads
}
```

**Implementation**:
```powershell
function Initialize-MyModule {
    # Setup module state, connect to services, etc.
    Write-Verbose "Module initialized"
}

function Cleanup-MyModule {
    # Clean up resources, close connections, etc.
    Write-Verbose "Module cleaned up"
}
```

### Template Hooks (Box-Specific)

Template hooks customize variable replacement in box template files:

**Location**: `boxers/<BoxName>/core/hooks.ps1`

**Available hooks**:
- `Hook-BeforeTemplateReplace` - Called before core template variable replacement
- `Hook-AfterTemplateReplace` - Called after core template variable replacement

**Example** (from AmiDevBox):
```powershell
# boxers/AmiDevBox/core/hooks.ps1

function Hook-BeforeTemplateReplace {
    <#
    .SYNOPSIS
        AmiDevBox-specific template replacements (C #define syntax).
    #>
    param(
        [string]$Text,
        [hashtable]$Variables,
        [bool]$ReleaseMode
    )

    # Replace #define VAR_NAME patterns for C header files
    foreach ($varName in $Variables.Keys) {
        $value = $Variables[$varName]
        $pattern = "(?m)^[ \t]*#define[ \t]+$varName[ \t]+.*$"
        $replacement = "#define $varName `"$value`""
        $Text = [regex]::Replace($Text, $pattern, $replacement)
    }

    return $Text
}
```

**Usage**: System automatically calls hooks if defined in box-specific hooks.ps1

---

## Built-in Commands

### Version Command

**Syntax**:
```
box version [module]
boxer version [module]
```

**Behavior**:

```powershell
# Show boxing system version
box version
# Output: Boxing v2.1.0

# Show specific module version
box version pkg
# Output: pkg v1.5.0 [built-in]

box version deploy
# Output: deploy v2.0.0 [custom] (from .box/modules/deploy/metadata.psd1)

boxer version
# Output: Boxer v2.1.0
```

**Version Sources**:
- **Embedded modules**: Version from boxing system
- **External modules with metadata**: Version from `metadata.psd1`
- **External modules without metadata**: No version ("unknown")

### Info Command

**Syntax**:
```
box info
boxer info
```

**Behavior**: Lists all registered commands with source and version

**Example output**:
```
Boxing Environment:
  Version: 2.1.0
  Mode: box
  Project: MonProjet

Embedded Commands:
  env       v2.1.0  Manage environment variables
  load      v2.1.0  Load boxing environment
  pkg       v2.1.0  Package management

External Commands (.box/modules/):
  deploy    v2.0.0  Deploy application
  docker    v1.0.0  Docker management

External Commands (modules/):
  build     v1.2.0  Build project
  test      ---     Run tests (no metadata)

Total: 7 commands (3 built-in, 4 custom)
```

**For boxer**:
```
Boxer Information:
  Version: 2.1.0
  Install Path: C:\Users\...\PowerShell\Boxing

Embedded Commands:
  install   v2.1.0  Install boxer
  update    v2.1.0  Update boxer
  config    v2.1.0  Configure boxer

External Commands:
  mycommand v1.0.0  Custom command

Total: 4 commands (3 built-in, 1 custom)
```

---

## Discovery & Loading Pipeline

### 1. Mode Detection
- Determine if running as `box` or `boxer` based on script name or embedded `$script:Mode`

### 2. Core Loading
- If embedded mode: Core functions already loaded
- If development mode: Load all `core/*.ps1` files

### 3. Module Discovery

**Priority order** (first match wins):

#### For BOXER:

1. **External modules** (if directory exists): `PowerShell/Boxing/modules/`
   - Scan for `.ps1` files (simple modules)
   - Scan for directories (subcommand modules)
   - Scan for directories with `metadata.psd1` (complex modules)

2. **Embedded modules** (fallback): Scan functions `Invoke-Boxer-*`
   - Extract command name from function name
   - Register with help from `Get-Help`

#### For BOX:

1. **User custom modules** (if directory exists): `MonProjet/.box/modules/`
   - Scan for `.ps1` files (simple modules)
   - Scan for directories (subcommand modules)
   - Scan for directories with `metadata.psd1` (complex modules)

2. **Project modules** (if directory exists): `MonProjet/modules/`
   - Same scanning logic as above

3. **Embedded modules** (fallback): Scan functions `Invoke-Box-*`
   - Extract command name from function name
   - Register with help from `Get-Help`

**Important**: External modules **override** embedded modules with the same name

### 4. Module Loading

#### Embedded Module (Function)
```powershell
# Already loaded as function: Invoke-Box-Hello
# Registered as: 'hello'
# CLI: box hello [args]
# Execution: & Invoke-Box-Hello @args
# Help: Get-Help Invoke-Box-Hello
```

#### External Module (Single File)
```powershell
# File: .box/modules/hello.ps1
# Registered as: 'hello' (overrides embedded if exists)
# CLI: box hello [args]
# Execution: & "path/to/hello.ps1" @args
# Help: Get-Help "path/to/hello.ps1"
```

#### External Module (Directory)
```powershell
# Directory: .box/modules/pkg/
#   - install.ps1
#   - list.ps1
# Registered as: 'pkg' with subcommands ['install', 'list']
# CLI: box pkg install
# Execution: & "path/to/pkg/install.ps1" @remainingArgs
# Help: Get-Help "path/to/pkg/install.ps1"
```

#### Complex Module (With Metadata)
```powershell
# Load metadata.psd1
# Validate required keys
# Register each command per metadata specification
# Dot-source all .ps1 files in module directory
# Validate handlers exist
# Call OnLoad hook if defined
```

### 5. Validation Rules

**For all modules**:
- Command names must be unique (external modules can override embedded)
- File paths in handlers must exist

**For embedded modules**:
- Must follow `Invoke-{Mode}-{Command}` naming pattern
- Must include comment-based help for `Get-Help` support

**For external modules**:
- Can be simple scripts (no function required)
- Can be functions (optional)
- Must include comment-based help for `box help` display

**For complex modules** (with metadata):
- `ModuleName`, `Version`, `Commands` are mandatory
- Every command in `Commands` must have a valid handler
- Dependencies must be available before module loads
- If `MinBoxingVersion` specified, current version must meet it

**Validation failures**:
- Block the specific module from loading
- Display clear error with module name and specific issue
- Continue loading other modules

---

## Dispatch Logic

### Command Resolution

```
User runs: box pkg install vscode --version 1.85.0
           │   │   │       │
           │   │   │       └─ Remaining args
           │   │   └───────── Subcommand
           │   └───────────── Command
           └───────────────── Mode
```

**Step 1**: Find registered command `pkg`

**Step 2**: Check command type
- **External file**: `.box/modules/pkg.ps1` → Execute file with all args
- **External directory**: `.box/modules/pkg/` → Look for subcommand OR default command
  - If subcommand provided: Look for `{subcommand}.ps1`
  - If NO subcommand: Look for `{module}.ps1` (default), else show help
- **Embedded function**: `Invoke-Box-Pkg` → Call function with all args
- **Complex metadata**: Check `Commands['pkg']` definition

**Step 3**: Route based on handler type

| Handler Type | Action |
|--------------|--------|
| `'script.ps1'` | Execute script: `& "path/to/script.ps1" @remainingArgs` |
| `'Function-Name'` | Call function: `& Function-Name @remainingArgs` |
| `'path::Function'` | Dot-source file, call function: `. path; & Function @remainingArgs` |
| `{ scriptblock }` | Execute scriptblock: `& $scriptblock @remainingArgs` |
| `Dispatcher = 'Func'` | Call dispatcher: `& Func -CommandPath @('cmd','sub') @remainingArgs` |

**Step 4**: Execute with error handling

### Argument Passing

**PowerShell handles argument passing automatically** via splatting (`@args`).

#### Simple Commands and Subcommands

Arguments are passed directly to scripts/functions using PowerShell's native parameter binding:

```powershell
# User runs:
box pkg install vscode --Version 1.85.0

# System calls:
& "install.ps1" 'vscode' --Version '1.85.0'

# Script receives via param():
param(
    [Parameter(Mandatory)]
    [string]$PackageName,    # ← Automatically bound to 'vscode'
    [string]$Version         # ← Automatically bound to '1.85.0'
)
```

**Examples**:

```powershell
# Case 1: Command with args
box mod arg1 arg2 --Arg3
→ & "mod.ps1" arg1 arg2 --Arg3

# Case 2: Subcommand with args
box mod subcmd arg1 arg2 --Arg3
→ & "subcmd.ps1" arg1 arg2 --Arg3

# Case 3: Default command detection
box pkg install vscode
→ System detects 'install' is a subcommand (not an arg)
→ & "install.ps1" 'vscode'
```

#### Dispatcher Commands

**Special case**: Dispatchers receive `-CommandPath` parameter to know their invocation context.

```powershell
function Invoke-Docker-Dispatcher {
    param(
        [string[]]$CommandPath,    # Command path: @('container', 'start')

        [Parameter(ValueFromRemainingArguments=$true)]
        [object[]]$Arguments       # All remaining args
    )

    # Dispatcher knows:
    # - Where it was called from: $CommandPath
    # - What args to forward: $Arguments

    if ($CommandPath[0] -eq 'container') {
        switch ($CommandPath[1]) {
            'start' { Start-Container @Arguments }
            'stop'  { Stop-Container @Arguments }
        }
    }
}
```

**System calls dispatcher**:

```powershell
# User runs:
box docker container start mycontainer --Force

# System calls:
& Invoke-Docker-Dispatcher -CommandPath @('container', 'start') 'mycontainer' --Force

# Dispatcher receives:
# $CommandPath = @('container', 'start')
# $Arguments = @('mycontainer', '--Force')
```

**CommandPath values**:
- `box docker` → `-CommandPath @('docker')`
- `box docker container` → `-CommandPath @('docker', 'container')`
- `box docker container start` → `-CommandPath @('docker', 'container', 'start')`

**Note**: `-CommandPath` is a **reserved parameter name** for dispatchers only. Regular handlers don't need it.

### Help System

**Help syntax** (unified approach):
```
box help                      → List all commands
box help command              → Show command help + list subcommands
box help command subcommand   → Show subcommand help
```

**Note**: `help` is treated as a regular subcommand, not a special flag.

#### Help by Module Type

**1. Embedded Module (Function)**
```powershell
box help            → Lists all commands with .SYNOPSIS
box help update     → Get-Help Invoke-Boxer-Update (full comment-based help)
```

**2. External Module (Single File)**
```powershell
# .box/modules/hello.ps1
box help        → hello    Say hello to someone (.SYNOPSIS)
box help hello  → Get-Help hello.ps1 (full .DESCRIPTION)
```

**3. External Module (Directory)**
```powershell
# .box/modules/pkg/
#   ├── pkg.ps1         (optional default command)
#   ├── install.ps1
#   ├── list.ps1
#   └── help.ps1 (optional)

box help             → pkg    Package management
box help pkg         → If help.ps1 exists: execute it
                       Otherwise: auto-generate list with .SYNOPSIS from each file
box help pkg install → Get-Help install.ps1

# Default command behavior
box pkg              → If pkg.ps1 exists: execute it
                       Otherwise: show 'box help pkg' (auto-generated subcommand list)
```

**4. Complex Module (With Metadata)**

**Default Command Behavior** (when calling without subcommand):

```powershell
# Case 1: Handler defined → Execute as default command
Commands = @{
    'deploy' = @{
        Handler = 'deploy.ps1'       # Default handler
        Synopsis = 'Deployment management'
        Description = 'Deploy application with various options'
        Subcommands = @{
            'start' = @{ Handler = 'start.ps1', Synopsis = 'Start deployment' }
            'stop' = @{ Handler = 'stop.ps1', Synopsis = 'Stop deployment' }
        }
    }
}

box deploy            → Executes 'deploy.ps1' (default command)
box deploy start      → Executes 'start.ps1'

# Case 2: Only Subcommands (no Handler) → Show help
Commands = @{
    'deploy' = @{
        Synopsis = 'Deployment management'
        Subcommands = @{
            'start' = @{ Handler = 'start.ps1', Synopsis = 'Start deployment' }
            'stop' = @{ Handler = 'stop.ps1', Synopsis = 'Stop deployment' }
        }
    }
}

box deploy            → Shows 'box help deploy' (lists subcommands)
box deploy start      → Executes 'start.ps1'

# Case 3: Dispatcher → Handles everything
Commands = @{
    'deploy' = @{
        Dispatcher = 'Invoke-Deploy-Dispatcher'
        Synopsis = 'Deployment management'
    }
}

box deploy            → Calls Dispatcher('', @())
box deploy start      → Calls Dispatcher('start', @())
```

**Handler formats**:
- `Handler = 'script.ps1'` → Execute script
- `Handler = 'FunctionName'` → Call function
- `Handler = 'path/file.ps1::FunctionName'` → Dot-source file, call function

**Help behavior**:
```powershell
box help              → deploy    Deployment management (Synopsis)
box help deploy       → If Handler defined: Get-Help on handler
                        If only Subcommands: Lists subcommands with Synopsis
                        If Dispatcher: Calls Dispatcher('help', @())
box help deploy start → If Description in metadata: show it
                        Otherwise: Get-Help start.ps1
```

**5. Module with Custom Dispatcher**
```powershell
# metadata.psd1
Commands = @{
    'docker' = @{
        Dispatcher = 'Invoke-Docker-Dispatcher'
        Synopsis = 'Manage Docker'
    }
}

box help        → docker    Manage Docker (Synopsis)
box help docker → Calls Dispatcher('help', @())
                  Dispatcher is responsible for handling help
```

**Example help listing output**:
```
Available commands:
  env       [built-in]  Manage environment variables
  load      [built-in]  Load boxing environment
  pkg       [built-in]  Package management
  deploy    [custom]    Deploy application
  build     [project]   Build project

Use 'box help <command>' for detailed information.
```

---

## Examples

### Example 1: Ultra-Simple Command

**File**: `.box/modules/sayhi.ps1`

```powershell
<#
.SYNOPSIS
Say hello to someone

.PARAMETER Name
Person to greet

.EXAMPLE
box sayhi World
#>

param([string]$Name = "World")

Write-Host "Hello, $Name!" -ForegroundColor Green
```

**Usage**:
```powershell
PS> box sayhi
Hello, World!

PS> box sayhi Alice
Hello, Alice!

PS> box help sayhi
# Shows parsed comment-based help (.DESCRIPTION, .PARAMETER, .EXAMPLE)
```

---

### Example 2: Simple Multi-Command Module

**Structure**:
```
.box/modules/deploy/
├── start.ps1
├── stop.ps1
└── status.ps1
```

**File**: `start.ps1`
```powershell
<#
.SYNOPSIS
Start deployment

.PARAMETER Environment
Target environment (dev/staging/prod)

.EXAMPLE
box deploy start --Environment prod
#>

param(
    [ValidateSet('dev','staging','prod')]
    [string]$Environment = 'dev'
)

Write-Host "Starting deployment to $Environment..." -ForegroundColor Cyan
# Deployment logic...
```

**Usage**:
```powershell
PS> box help deploy
Available subcommands:
  start   Start deployment
  stop    Stop deployment
  status  Check deployment status

PS> box deploy start -Environment prod
Starting deployment to prod...

PS> box help deploy start
# Shows start.ps1 full comment-based help
```

---

### Example 3: Complex Module with Metadata

**Structure**:
```
.box/modules/docker/
├── metadata.psd1
├── container.ps1
├── image.ps1
└── helpers/
    └── registry.ps1
```

**File**: `metadata.psd1`
```powershell
@{
    ModuleName = 'docker'
    Version = '1.0.0'
    Description = 'Docker management module'

    Commands = @{
        'container' = @{
            # No Handler → 'box docker container' shows help (lists subcommands)
            Synopsis = 'Manage Docker containers'
            Description = 'Create, start, stop, and manage Docker containers lifecycle'
            Subcommands = @{
                'list' = @{
                    Handler = 'container-list.ps1'
                    Synopsis = 'List containers'
                    Description = 'Display all Docker containers with status and details'
                }
                'start' = @{
                    Handler = 'container-start.ps1'
                    Synopsis = 'Start container'
                    Description = 'Start one or more stopped containers'
                }
                'stop' = @{
                    Handler = 'container-stop.ps1'
                    Synopsis = 'Stop container'
                    Description = 'Stop one or more running containers'
                }
            }
        }
        'image' = @{
            # Has Handler → 'box docker image' executes default handler
            Handler = 'image.ps1'  # Default: shows image status/info
            Synopsis = 'Manage Docker images'
            Description = 'Pull, list, and manage Docker images in local registry'
            Subcommands = @{
                'pull' = @{
                    Handler = 'image-pull.ps1'
                    Synopsis = 'Pull image'
                    Description = 'Download Docker image from registry'
                }
                'list' = @{
                    Handler = 'image-list.ps1'
                    Synopsis = 'List images'
                    Description = 'Display all Docker images in local registry'
                }
            }
        }
    }

    PrivateFunctions = @('Connect-Registry', 'Parse-Dockerfile')
}
```

**File**: `container-list.ps1`
```powershell
<#
.SYNOPSIS
List Docker containers

.DESCRIPTION
Displays all Docker containers with their status

.PARAMETER All
Show all containers (default shows only running)

.EXAMPLE
box docker container list
#>
param([switch]$All)

if ($All) {
    docker ps -a
} else {
    docker ps
}
```

**Usage**:
```powershell
PS> box help docker
# Shows: container, image subcommands

PS> box help docker container
# Shows: list, start, stop

PS> box docker container list
# Executes: container-list.ps1
```

---

## Build Process

### Compiling Modules into Embedded Functions

**Build script** (`scripts/build-boxer.ps1` or `scripts/build-box.ps1`) process:

1. **Load all source modules** from `modules/{mode}/`
2. **Transform each module file** into a function:
   - Wrap content in `function Invoke-{Mode}-{CommandName} { ... }`
   - Preserve comment-based help
   - Preserve parameters
3. **Include shared helpers** from `modules/shared/` as private functions
4. **Include core** from `core/` as utility functions
5. **Set embedded flag**: `$script:IsEmbedded = $true`
6. **Append bootstrapper** from `boxing.ps1`
7. **Write final monolithic file**: `boxer.ps1` or `box.ps1`

**Example transformation**:

```powershell
# INPUT: modules/boxer/update.ps1
<#
.SYNOPSIS
Update boxer
.PARAMETER Version
Specific version to install
#>
param([string]$Version)
Write-Host "Updating to version $Version..."

# ↓ BUILD PROCESS ↓

# OUTPUT in boxer.ps1:
function Invoke-Boxer-Update {
    <#
    .SYNOPSIS
    Update boxer
    .PARAMETER Version
    Specific version to install
    #>
    param([string]$Version)
    Write-Host "Updating to version $Version..."
}
```

**Result**: Single-file distribution with all modules as embedded functions, discoverable via `Get-Command Invoke-{Mode}-*` and help via `Get-Help`.

---

## Migration from v1 (MODULES.md)

### Breaking Changes

1. **No more mandatory `Invoke-{Mode}-{Command}` functions for external modules**
   - Old: Must define `Invoke-Box-Hello` everywhere
   - New: External modules are just scripts; embedded modules still use functions

2. **Directory = subcommands by default**
   - Old: Need dispatcher function
   - New: Auto-discovered from directory structure

3. **Metadata format changed** (for complex modules)
   - Old: Flat `Commands = @('cmd1', 'cmd2')`
   - New: Nested `Commands = @{ 'cmd1' = @{ Handler = '...' } }`

4. **No more modules/shared/ in runtime**
   - Old: `modules/shared/` scanned at runtime
   - New: `modules/shared/` only exists in DevBoxFoundry sources; compiled into embedded

### Migration Path

**For users adding external modules**: Remove wrapper function, keep script logic

```powershell
# OLD (v1)
function Invoke-Box-Hello {
    param([string]$Name)
    Write-Host "Hello $Name"
}

# NEW (v2) - in .box/modules/hello.ps1
<#
.SYNOPSIS
Greet someone
.PARAMETER Name
Person to greet
#>
param([string]$Name)
Write-Host "Hello $Name"
```

**For DevBoxFoundry source modules**: Keep as-is (build process handles wrapping)

```powershell
# modules/box/load.ps1 (unchanged)
<#
.SYNOPSIS
Load boxing environment
#>
param()
# ... logic ...
```

**For complex modules**: Update metadata.psd1 format

```powershell
# OLD (v1)
@{
    ModuleName = 'pkg'
    Commands = @('install', 'uninstall', 'list')
}

# NEW (v2)
@{
    ModuleName = 'pkg'
    Commands = @{
        'install' = @{ Handler = 'install.ps1' }
        'uninstall' = @{ Handler = 'uninstall.ps1' }
        'list' = @{ Handler = 'list.ps1' }
    }
}
```

---

## Implementation Checklist

### Core Changes
- [ ] Update `Import-ModeModules` to check external directories first
- [ ] Add external module directory detection (check if exists)
- [ ] Implement priority system (external > embedded)
- [ ] Update `Invoke-Command` dispatcher with new routing logic
- [ ] Support direct script execution for external modules (no function required)

### Discovery
- [ ] Scan `PowerShell/Boxing/modules/` for boxer external modules
- [ ] Scan `MonProjet/.box/modules/` for box user custom modules
- [ ] Scan `MonProjet/modules/` for box project modules
- [ ] Use `Get-Command Invoke-{Mode}-*` for embedded module discovery
- [ ] Auto-discover directory-based subcommands
- [ ] Implement metadata.psd1 loader and validator for complex modules

### Help System
- [ ] Collect help from embedded functions using `Get-Help Invoke-{Mode}-*`
- [ ] Scan external module directories for help
- [ ] Use `Get-Help` on external script files
- [ ] Merge embedded + external help with priority tags
- [ ] Display source indicator ([built-in], [custom], [project])

### Build Process
- [ ] Update build scripts to wrap modules in `Invoke-{Mode}-{Command}` functions
- [ ] Include shared helpers as private functions
- [ ] Set `$script:IsEmbedded = $true` in compiled files
- [ ] Preserve comment-based help during compilation
- [ ] Ensure `Get-Help` works on generated functions

### Testing
- [ ] Test embedded module execution
- [ ] Test `Get-Help` on embedded functions
- [ ] Test external module override
- [ ] Test `Get-Help` on external scripts
- [ ] Test directory-based subcommands
- [ ] Test help system with mixed sources
- [ ] Test metadata-based complex modules
- [ ] Test priority order (external > embedded)

### Migration
- [ ] Update existing modules to v2 format
- [ ] Create migration guide for users
- [ ] Update documentation and examples

---

## Design Decisions & Rationale

### Why allow scripts without functions for external modules?

**Simplicity for users**: Most custom commands are simple one-liners. Forcing a function wrapper adds boilerplate without value. Users just drop a `.ps1` file in `modules/` and it works.

### Why keep `Invoke-{Mode}-{Command}` functions for embedded modules?

**Distribution simplicity**: Single-file boxer.ps1/box.ps1 with all code embedded. Functions are easily discovered with `Get-Command Invoke-*` and PowerShell's native `Get-Help` works out of the box.

### Why use `Get-Help` instead of custom metadata structure?

**Leverage PowerShell**: PowerShell's `Get-Help` already parses comment-based help, formats output, supports `-Full`/`-Examples`/`-Parameter` flags. No need to reinvent the wheel. Less code, fewer bugs.

### Why keep metadata files as option?

**Advanced use cases**: Some modules need custom dispatch, validation, dependencies. Declarative metadata enables this while keeping simple modules simple.

### Why auto-discover subcommands from directories?

**Convention over configuration**: `pkg/install.ps1` is self-documenting. No need to maintain a separate registry.

### Why separate embedded (functions) from external (scripts)?

**Distribution vs customization**: Embedded modules in single file (boxer.ps1/box.ps1) make distribution trivial. External modules give users full customization power without modifying the core file.

### Why keep modules/shared/ in DevBoxFoundry sources?

**Code reuse during development**: Shared helpers avoid duplication between boxer and box modules during development. After build, they're compiled into both outputs as needed, so end users never see the "shared" concept.

---

**End of Specification**
