# Help Implementation Guide for DevBoxFoundry Core

Audience: Boxing core contributors (boxer/box, modules, discovery, renderer).
Goal: keep help output unified, non-regressing, and aligned with specs 001/002/003 and MODULES2.

## Pipeline Overview
- Source data: registered commands from discovery (embedded functions, external scripts, overrides, metadata-based modules) with precedence external/project > shared > embedded; metadata Hidden entries stay invokable but are filtered from help listings.
- Text sources:
  - Primary: comment-based help (.SYNOPSIS, .DESCRIPTION) on functions/scripts.
  - Metadata modules: `Synopsis`/`Description` fields per command/subcommand; fallback to handler comment-based help if Description missing.
- Renderer: unified helpers in core/help.ps1 build HelpProfile from the registry, wrap text at 100 cols, and render top-level/command/subcommand views; no formatting elsewhere.
- Entry points: `boxer help`, `box help`, and `help` paths for commands/subcommands call the renderer helpers with the current registry snapshot.

## Required Behaviors
- Top-level help: show title/description (boxer or box) + list of registered commands with synopsis; provide defaults if metadata missing; wrap descriptions/synopsis ≤100 cols.
- Command help: show command title/description + list of subcommands (if any) with synopsis; omit subcommand section when none exist.
- Subcommand help: show title/description only (no subcommand list).
- Dispatcher help: metadata dispatcher paths handle help when declared; otherwise fall back to handler/help handler/renderer.
- Unknown command/subcommand: clear error and pointer to top-level help.
- Custom headers (e.g., ASCII art) from box metadata may be shown above description; fall back cleanly if absent.

## Discovery Alignment
- Use the same registry produced by boxing.ps1 discovery: embedded functions (Invoke-{Mode}-*), external modules, metadata commands, directory subcommands.
- Respect hidden flags: metadata `Hidden = $true` should omit from listings but remain invokable.
- Keep pkg scoped to box mode; boxer help must not surface box-only commands.

## Rendering Rules
- Inputs to renderer: title, description, optional custom header, list of commands (name + synopsis + source), optional subcommand list, optional description fallback; wrap width 100; no-commands message supplied.
- Outputs: plain text layout; readable without color; consistent section ordering (Header → Description → Commands/Subcommands).
- Fallbacks: when synopsis/description missing, inject standard default strings (no blank lines).
- Hidden: metadata Hidden entries filtered before render; runtime invocation unchanged.
- Performance: target <2s for any help call in local env; avoid heavy runtime resolution during render (discovery should precompute registry).

## Extraction Rules
- Comment-based help: rely on Get-Help against functions (embedded) or scripts (external) when metadata Description absent.
- Metadata: prefer `Synopsis`/`Description` when provided; synopsis is required for commands/subcommands.
- Dispatcher modules: if no handler/subcommands, dispatcher must print help; renderer should display Synopsis/Description from metadata for dispatcher-registered commands and list the discovered subcommands when available.

- [ ] `boxer help` shows non-empty title/description + all boxer commands with synopsis.
- [ ] `box help` shows box title/description (or default) + commands with synopsis respecting precedence and Hidden filtering.
- [ ] `box help <cmd>`: title/description present; subcommands listed only when they exist; hidden items stay hidden.
- [ ] `box help <cmd> <sub>`: shows subcommand title/description; no subcommand list.
- [ ] Metadata module with Description absent falls back to handler comment-based help.
- [ ] Dispatcher or subcommands-only module shows help when invoked without actionable subcommand (dispatcher receives CommandPath + 'help').
- [ ] Help output unchanged for existing commands (compare before/after samples where available).
- [ ] Performance spot-check: typical help call returns <2s locally.

## Implementation Notes
- Centralize display utilities in core/help.ps1; forbid ad-hoc formatting in modules.
- Registry should carry source info (embedded/external/shared) for potential display/debug; keep user output concise.
- When adding new commands, ensure comment-based help meets the module author checklist so renderer has data to show.
- Keep ASCII-only output; avoid dependency on console color for meaning.
