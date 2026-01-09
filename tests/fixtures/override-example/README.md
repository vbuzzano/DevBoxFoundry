# Box Override Mechanism Test Fixture

This directory demonstrates the box-specific module override mechanism.

## Structure

```
.box/
  modules/
    install.ps1    # Overrides core install command with custom logic
```

## How It Works

1. **Priority System**: Boxing.ps1 loads modules with priority:
   - Priority 1: `.box/modules/*.ps1` (box-specific overrides)
   - Priority 2: `modules/box/*.ps1` (core modules)

2. **Function Naming**: Override modules MUST use the same function name as core:
   - Example: `Invoke-Box-Install` for install command
   - Pattern: `Invoke-Box-<CommandName>`

3. **Fallback**: If override module fails to load, core module is used

## Testing

To test the override mechanism:

```powershell
# Navigate to this fixture directory
cd tests\fixtures\override-example

# Run box install command
box install package-name
```

Expected behavior:
- Custom install module executes (purple header)
- Core install module does NOT execute

## Use Cases

Box developers can override modules to:
- Integrate proprietary tooling
- Validate box-specific dependencies
- Customize package sources
- Add telemetry or logging
- Implement custom workflows
