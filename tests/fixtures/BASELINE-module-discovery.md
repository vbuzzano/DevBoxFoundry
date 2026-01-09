# Baseline: Module Discovery Logic in boxing.ps1

**Date**: 2026-01-09
**Purpose**: Document current module discovery behavior before modifications (T003)

## Current Module Loading Sequence

### Phase 1: Core Libraries
**Function**: `Import-CoreLibraries`
**Location**: Lines 56-76 in boxing.ps1
**Behavior**:
- Loads all `*.ps1` files from `core/` directory
- Sorted alphabetically by name
- Executed via dot-sourcing (`. $file.FullName`)
- Skipped if `$script:IsEmbedded` is true (compiled version)

### Phase 2: Mode-Specific Modules
**Function**: `Import-ModeModules`
**Location**: Lines 78-119 in boxing.ps1
**Behavior**:
- Loads from `modules/$Mode/` (either `modules/boxer/` or `modules/box/`)
- All `*.ps1` files sorted alphabetically
- Registers commands: filename → command name (e.g., `install.ps1` → `install` command)
- Stores in `$script:Commands` hashtable
- Skipped if embedded, but still calls `Register-EmbeddedCommands`

### Phase 3: Shared Modules
**Function**: `Import-SharedModules`
**Location**: Lines 148-193 in boxing.ps1
**Behavior**:
- Searches for `metadata.psd1` files recursively in `modules/shared/`
- Loads all `*.ps1` files in each module directory
- Registers commands from metadata `Commands` array
- Stores module directory path in `$script:LoadedModules`

## Current Search Paths (Priority Order)

1. `core/*.ps1` - Core libraries
2. `modules/boxer/*.ps1` OR `modules/box/*.ps1` - Mode-specific modules
3. `modules/shared/**/metadata.psd1` → load adjacent `*.ps1` files

## Key Observations

### No .box/modules/ Override Support
**Current State**: Module discovery does NOT check project-level `.box/modules/` directory
**Impact**: Box developers cannot override core modules with box-specific implementations

### No Verbose Logging for Module Sources
**Current State**: `Write-Verbose` shows "Loaded module: $Mode/$($file.Name)" but doesn't indicate source priority
**Impact**: Cannot distinguish between core, mode, shared, or override modules in logs

### Command Registration Pattern
**Pattern**: `Invoke-{Mode}-{CommandName}` (e.g., `Invoke-Box-Install`)
- Mode-specific modules register as: `$script:Commands[$commandName] = $file.FullName`
- Shared modules register as: `$script:Commands[$cmd] = $moduleName`
- No collision detection between module types

## Required Changes for Spec 001

### T004: Add .box/modules/ Priority
Modify `Import-ModeModules` to check `.box/modules/` before `modules/$Mode/`
- Search order: `.box/modules/*.ps1` → `modules/$Mode/*.ps1`
- First match wins (box override takes precedence)

### T005: Add Verbose Logging
Enhance `Write-Verbose` to show module source:
- `"Loaded module (box-override): install.ps1"`
- `"Loaded module (core): install.ps1"`

### T006: Shared Module Helpers
Create helper functions in `modules/shared/pkg/` for package subcommands:
- `Show-PackageList`
- `Validate-PackageDependencies`
- `Show-PackageState`

## Testing Baseline

Before modifications, the following should work:
- ✅ `boxer list` loads from `modules/boxer/list.ps1`
- ✅ `box install` loads from `modules/box/install.ps1`
- ✅ Shared modules with metadata.psd1 load correctly

After modifications (Phase 2), the following should work:
- ✅ `.box/modules/install.ps1` overrides `modules/box/install.ps1`
- ✅ Verbose logging shows override source
- ✅ Fallback to core module when no override exists
