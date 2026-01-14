# Tasks: Module System Gap Alignment

**Input**: Design documents from `/specs/002-modules-gap-spec/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

## Phase 1: Setup (Shared Infrastructure)

- [X] T001 [P] Create fixtures root for module loading tests in `tests/fixtures/modules-gap/`

---

## Phase 2: Foundational (Blocking Prerequisites)

- [X] T002 [P] Add Pester helper to build temp module trees in `tests/fixtures/modules-gap/helpers.ps1`
- [X] T003 Scaffold shared Describe blocks for module loading in `tests/test-module-loader.ps1`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Discovery Contract Enforced (Priority: P1) 🎯 MVP

**Goal**: Enforce discovery/override contract so missing metadata or overrides are handled predictably.
**Independent Test**: Loading modules with/without required metadata and with overrides yields predictable registration and errors.

### Tests
- [X] T004 [P] [US1] Add Pester test blocking shared module missing `metadata.psd1` or required keys in `tests/test-module-loader.ps1`
- [X] T005 [P] [US1] Add Pester test asserting project override in `.box/modules` wins over `modules/<mode>` in `tests/test-module-loader.ps1`

### Implementation
- [X] T006 [US1] Enforce required metadata keys (`ModuleName`, `Commands`) with clear error in `boxing.ps1`
- [X] T007 [US1] Ensure override precedence and log applied source in `boxing.ps1`

**Checkpoint**: User Story 1 independently testable

---

## Phase 4: User Story 2 - Shared Module Quality Guardrails (Priority: P2)

**Goal**: Validate alignment between metadata and entrypoints; block mismatches.
**Independent Test**: Modules with mismatched metadata/entrypoints are rejected with actionable feedback; complete modules register cleanly.

### Tests
- [X] T008 [P] [US2] Add Pester test blocking metadata commands without `Invoke-<Mode>-<Command>` entrypoints in `tests/test-module-loader.ps1`
- [X] T009 [P] [US2] Add Pester test blocking functions not declared in metadata unless marked private in `tests/test-module-loader.ps1`

### Implementation
- [X] T010 [US2] Validate metadata-declared commands map to functions before registration in `boxing.ps1`
- [X] T011 [US2] Add support for `PrivateFunctions` allowlist to skip registration of helper functions in `boxing.ps1`

**Checkpoint**: User Story 2 independently testable

---

## Phase 5: User Story 3 - Embedded Build Parity (Priority: P3)

**Goal**: Embedded registration matches disk-based discovery without filesystem access.
**Independent Test**: Function-scan registration for embedded builds produces the same base command list and dedupes subcommands.

### Tests
- [X] T012 [P] [US3] Add Pester test comparing embedded function scan vs disk discovery for baseline commands in `tests/test-module-loader.ps1`
- [X] T013 [P] [US3] Add Pester test ensuring subcommand suffixes are stripped and duplicates deduped in embedded mode in `tests/test-module-loader.ps1`

### Implementation
- [X] T014 [US3] Update `Register-EmbeddedCommands` to strip subcommand suffixes and dedupe base commands in `boxing.ps1`

**Checkpoint**: User Story 3 independently testable

---

## Final Phase: Polish & Cross-Cutting Concerns

- [ ] T015 [P] Update discovery/validation rules in `MODULES.md`
- [ ] T016 Refresh quickstart guidance to reflect validation behaviors in `specs/002-modules-gap-spec/quickstart.md`

---

## Dependencies & Execution Order

- Setup (Phase 1) → Foundational (Phase 2) → User Stories in priority order: US1 (P1) → US2 (P2) → US3 (P3) → Polish.
- User stories can run in parallel after Phase 2, but US1 should complete first for MVP readiness.

## Parallel Opportunities

- P-marked tasks can run concurrently: fixture/helper setup (T001-T002), Pester test additions per story (T004-T005, T008-T009, T012-T013), and doc updates (T015-T016).
- Different stories can be staffed in parallel once Phase 2 completes, provided they touch distinct code paths.

## Implementation Strategy

- MVP: Deliver US1 (metadata enforcement + overrides) with passing tests.
- Incremental: Add US2 (metadata-entrypoint alignment) then US3 (embedded parity), validating each story independently.
