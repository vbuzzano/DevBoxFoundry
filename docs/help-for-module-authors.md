# Help Implementation Guide for Module Authors

Audience: external module authors (single-file, directory, metadata-based).
Goal: ensure your commands surface consistent help in `box help` / `boxer help` using the unified renderer.

## Core Principles
- Always provide comment-based help at the top of every script: .SYNOPSIS (one line), .DESCRIPTION (detail), .PARAMETER, .EXAMPLE.
- Keep synopsis under ~60 chars; this is what shows in command listings (wrapped at 100 cols by renderer).
- Place the help block before `param()` so PowerShell picks it up.
- Avoid empty placeholders; supply defaults or concise fallbacks.

## Single-File Module (`modules/mycmd.ps1`)
- Required: comment-based help with at least .SYNOPSIS + one .EXAMPLE.
- Invocation: `box mycmd ...` (or `boxer` if in boxer scope).
- Help check: `box help mycmd` should display your synopsis and description.
- Testing: run `Get-Help "${PSScriptRoot}/mycmd.ps1" -Detailed` to validate formatting.

## Directory Module (multi-file) (`modules/pkg/*.ps1`)
- Layout: root files are subcommands; optional default `{command}.ps1` executes when no subcommand is given.
- Each subcommand file needs its own comment-based help; synopsis is shown in the subcommand list.
- If no default file exists, calling `box pkg` should show help (list all `.ps1` subcommands with their synopsis). Hidden subcommands are not listed.
- Helpers go under `helpers/`; dot-source them from each subcommand as needed.
- Test: `box help pkg` (list) and `box help pkg install` (detail) to confirm synopsis/description appear.

## Metadata Module (`modules/{command}/metadata.psd1`)
- Use when you need declarative routing, default+subcommands, or dispatcher control.
- In `metadata.psd1`, set for each command/subcommand:
  - `Synopsis` (required) → appears in listings.
  - `Description` (optional) → appears in detailed help; if absent, falls back to handler comment-based help.
  - `Hidden = $true` to hide from listings (still callable; renderer filters these entries).
- Handlers: `Handler = 'file.ps1'` / `FunctionName` / `file.ps1::Function` / `Dispatcher = 'Fn'` (dispatcher must accept `-CommandPath`).
- With dispatcher or “subcommands only”, you own the help output; ensure you print a clear list of subcommands plus synopsis. Dispatcher will also receive help path (`CommandPath + 'help'`).
- Auto-sourcing: all `.ps1` files are dot-sourced; keep helper-only functions in `PrivateFunctions` to avoid exposure.

## Embedded Modules (core contributions)
- Same rules as external, but built into `boxer.ps1` / `box.ps1` via function wrapping.
- Write comment-based help in the source file; build preserves it. Function names become `Invoke-{Mode}-{Command}`.
- Test both source (`Get-Help ./modules/box/env.ps1`) and built (`box help env`).

## Quality Checklist (module level)
- [ ] `.SYNOPSIS` present and concise (<60 chars)
- [ ] `.DESCRIPTION` explains purpose and behaviors
- [ ] Each parameter documented; examples include typical usage
- [ ] Default command (if any) documented in synopsis/description
- [ ] Subcommands listed with clear synopsis
- [ ] Metadata commands each have Synopsis (and Description when needed)
- [ ] Dispatcher handles `-CommandPath` and prints help when invoked without actionable subcommand
- [ ] `box help {cmd}` and `box help {cmd} {sub}` show the expected text

## Tips
- Prefer real examples over placeholders; keep them runnable.
- Use plain text; avoid color reliance so output stays readable everywhere.
- If a command is experimental, mark `Hidden = $true` until ready.
- Reuse wording across synopsis/description to stay consistent with other Boxing modules.
