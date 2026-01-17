# Module System: Gap Analysis & Action Plan

Goal: align the implementation with the behaviors documented in `MODULES.md` and ensure the spec 001 expectations are fully met.

## Gaps vs Spec 001
- **Dynamic discovery not formalized in spec**: Spec 001 requires the pkg dispatcher and override order, but it does not codify dynamic discovery from filenames or metadata. Implementation should keep dynamic discovery as the source of truth.
- **Shared modules metadata contract**: Spec does not state that `modules/shared/<module>/metadata.psd1` is mandatory with `Commands` populated. Implementation relies on it; document and enforce.
- **Embedded registration**: Spec omits `Register-EmbeddedCommands` scanning functions `Invoke-<Mode>-*` for embedded builds. Implementation must preserve this behavior.
- **No static command registry**: Spec does not forbid hardcoded command lists. Implementation must keep runtime discovery only.

## Current State Observations
- `boxing.ps1` implements discovery via filenames for mode modules and via `metadata.psd1` for shared modules; commands are registered dynamically.
- `modules/shared/pkg/metadata.psd1` declares commands; `modules/box/pkg.ps1` implements dispatcher. No `Invoke-Boxer-Pkg` equivalent (pkg is box-only today).
- Overrides: `.box/modules/*.ps1` load before `modules/<mode>/*.ps1` (matches spec FR-026..029).

## Actions to fully align
1) **Lock dynamic discovery as contract**
   - Add brief doc note in spec or adjacent docs pointing to `MODULES.md` for discovery rules (no code change needed).
   - Ensure no hardcoded command lists exist (quick scan before release).

2) **Shared module metadata enforcement**
   - Validate presence of `metadata.psd1` for any shared module directory; fail with clear error if missing `ModuleName` or `Commands`.
   - Optional: add a small validator function in core/shared load path to check required keys.

3) **Embedded command registration**
   - Confirm embedded build path still calls `Register-EmbeddedCommands` and that it strips subcommand suffixes correctly.
   - Add a note in docs (or spec addendum) that embedded builds rely on function name scan.

4) **pkg dispatcher completeness**
   - Verify all commands declared in `modules/shared/pkg/metadata.psd1` have callable entrypoints: `install`, `uninstall`, `list`, `validate`, `state` via `Invoke-Box-Pkg` routing. (Currently present.)
   - If boxer-mode exposure is desired, add `Invoke-Boxer-Pkg` (spec doesn’t require it; only box-mode is expected for pkg).

5) **Override order regression guard**
   - Add/maintain tests that `.box/modules` overrides core, and shared modules load after mode modules.

## Optional refinements (if time allows)
- Provide a small helper cmdlet to list discovered commands and their source (box override vs core vs shared) for debugging.
- Add a lint step to ensure every `metadata.psd1` command has a matching `Invoke-<Mode>-<Command>` entrypoint somewhere in the loaded scope.

## Definition of done
- Dynamic discovery behaviors are documented and preserved (no static registry).
- Shared modules require valid `metadata.psd1` with `Commands`; loader validates keys.
- Embedded builds register commands via function scan without disk access.
- pkg dispatcher routes all declared commands; helps unknown subcommand.
- Tests cover override priority and pkg dispatcher happy/error paths.
