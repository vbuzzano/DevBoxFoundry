# Module System

Reference for how Boxing discovers, loads, and dispatches commands for modules. All names and examples are in English; commands exposed to the CLI remain the same.

## Discovery Pipeline (from `boxing.ps1`)
- Detect mode: `box` or `boxer` via `Initialize-Mode`.
- Load core libraries: `core/*.ps1` via `Import-CoreLibraries`.
- Load mode modules: `Import-ModeModules -Mode <box|boxer>` finds `.ps1` files, registers commands from filenames, and dot-sources the files.
- Load shared modules: `Import-SharedModules` scans `modules/shared/**/metadata.psd1`, loads all `.ps1` in each module directory, and registers commands listed in metadata.
- Validate shared modules: required metadata keys (`ModuleName`, `Commands`), every declared command must have an entrypoint in the module files, and any `Invoke-*` function not listed in `Commands` must be marked in `PrivateFunctions` or it fails load.
- Dispatch: `Invoke-Command` builds `Invoke-<Mode>-<Command>` and runs it when the command is registered.

## Module Types
### Mode modules (single-command or dispatcher)
- Location priority: `.box/modules/*.ps1` (project override) > `modules/<mode>/*.ps1` (built-in).
- Command name = filename without extension. `modules/box/install.ps1` → CLI `box install` → entry `Invoke-Box-Install`.
- Each file must expose `Invoke-<Mode>-<Command>`; helpers can live in the same file or subfolders. Subcommands are handled by the entry function (e.g., `Invoke-Box-Env` routes to `Invoke-Box-Env-List/Load/...`).
- No static registry: commands are discovered at runtime from filenames (or from embedded function scan).

### Shared modules (multi-command)
- Location: `modules/shared/<module>/` with a mandatory `metadata.psd1`.
- Metadata keys:
  - `ModuleName` (e.g., `pkg`)
  - `Version`, `Description`
  - `Commands` (array of command names exposed to the CLI)
  - `DefaultCommand` (optional)
  - `RequiredCoreModules` (dependencies on core scripts)
- Optional: `PrivateFunctions` (array) for helper functions that should not register as commands.
- Load behavior: all `.ps1` in the module directory are dot-sourced; commands listed in `Commands` are registered if their `Invoke-<Mode>-<Command>` entrypoints live in the same module directory. Functions following `Invoke-<Mode>-<Something>` that are not listed in `Commands` must be in `PrivateFunctions`, otherwise the module load fails with an undeclared function error. Missing entrypoints for declared commands also fail load with a targeted error listing the missing items.
- Mode-level entrypoints can delegate to shared logic (e.g., `modules/box/pkg.ps1` dispatches `install/list/validate/uninstall/state` using shared `pkg` helpers).

## Embedded builds
- When `IsEmbedded` is `$true`, core/shared code is already loaded. `Register-EmbeddedCommands` scans functions named `Invoke-<Mode>-*`, strips everything after the first dash to get the base command, deduplicates duplicates, and enables dispatch without reading module files from disk.

## Naming and structure conventions
- Entry function: `Invoke-<Mode>-<Command>` (mode = `Box` or `Boxer`; command is lowercase in CLI, PascalCase in function name).
- Subcommands: implement inside the entry file or its subfolder, and route via a dispatcher (switch/case) in the entry function.
- Helpers: keep private/helper functions in the same module folder; they do not need the `Invoke-` prefix unless dispatched directly.

## Minimal examples
**Simple command** (`modules/box/hello.ps1`):
```powershell
function Invoke-Box-Hello {
    param([string[]]$Args)
    Write-Host "Hello from box" -ForegroundColor Cyan
}
```

**Shared module metadata** (`modules/shared/example/metadata.psd1`):
```powershell
@{
    ModuleName = 'example'
    Version = '1.0.0'
    Description = 'Sample shared module'
    Commands = @('example')
    RequiredCoreModules = @('common')
}
```

**Mode dispatcher using shared logic** (`modules/box/example.ps1`):
```powershell
function Invoke-Box-Example {
    param([string]$Subcommand, [string[]]$Args)
    switch ($Subcommand) {
        'do' { Invoke-Example-Do @Args }
        default { Write-Error "Unknown subcommand: $Subcommand" }
    }
}
```

## Overrides and priority
- Project overrides live in `.box/modules/` and win over built-in modules with the same command name.
- Shared modules can be reused by both modes; mode modules decide how to surface them to the CLI (dispatcher vs direct entrypoint).

## What to implement when adding a module
1. Choose type: simple (one command) or dispatcher (multiple subcommands) or shared module with metadata.
2. Place files in the right location and respect naming (`Invoke-<Mode>-<Command>`).
3. For shared modules, add `metadata.psd1` with `Commands` populated; ensure functions exist for those commands.
4. Keep everything discoverable dynamically—no hardcoded command lists.
