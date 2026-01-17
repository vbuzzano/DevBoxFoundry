# Quickstart

1) Prerequisites
- PowerShell 7+ installed; run commands from repo root.
- Familiarity with module layout in `MODULES.md` (`modules/box`, `modules/boxer`, `modules/shared`).

2) Author or fix a shared module
- Add `modules/shared/<name>/metadata.psd1` with `ModuleName` and `Commands` populated (plus optional `DefaultCommand`, `RequiredCoreModules`, `PrivateFunctions`).
- Ensure each command listed has an `Invoke-<Mode>-<Command>` function in the module files; list helper-only functions under `PrivateFunctions` to avoid undeclared-function errors.
- Run loader validation (tests) to confirm missing metadata, missing entrypoints, or undeclared functions are blocked with clear errors.

3) Override a mode command
- Place the override in `.box/modules/<command>.ps1` using `Invoke-<Mode>-<Command>` naming.
- Verify override precedence by loading the CLI (or running targeted tests) and confirming the override source is registered.

4) Validate pkg dispatcher
- Keep `pkg` as box-only; ensure subcommands `install`, `uninstall`, `list`, `validate`, `state` are routed by `Invoke-Box-Pkg`.
- Check unknown subcommands return a guided error and that help reflects the registered commands.

5) Embedded build parity
- For embedded distributions, confirm functions named `Invoke-<Mode>-*` are present before registration.
- Expect `Register-EmbeddedCommands` to strip subcommand suffixes (after the first dash), dedupe duplicates, and register base commands matching disk-based discovery.

6) Testing (Pester)
- Use Pester suites in `tests/` (or new targeted cases) to cover metadata validation, override precedence, pkg dispatcher routes, and embedded scan behavior.
