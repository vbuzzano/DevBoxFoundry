# Tasks: Module System v2 Alignment

**Input**: Design documents from `/specs/003-modules-v2-alignment/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Tests are requested; include Pester coverage per story.

## Commit Guidelines (from git.instructions.md)

**CRITICAL - Rule #8**: NO spec/task references in commit messages unless absolutely needed
- ❌ WRONG: "Implement task T001 from spec"
- ✅ CORRECT: "Align boxing.ps1 external module routing"

**Commit format**:
- One commit per file or logical group
- Simple & factual
- No task IDs or phase numbers

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (Shared Infrastructure)

 - [X] T001 Create external single-file fixture `tests/fixtures/external-single/hello.ps1` for routing tests
 - [X] T002 [P] Create directory-module fixture `tests/fixtures/external-dir/foo/{foo.ps1,bar.ps1}` for default/subcommand tests

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Common test harness and fixtures required by all user stories

- [X] T003 Add Pester harness `tests/test-module-discovery-v2.ps1` covering external/embedded routing scenarios
 - [X] T004 [P] Add fixture metadata module `tests/fixtures/metadata-sample/{metadata.psd1,handler.ps1,dispatcher.ps1,help.ps1}` for metadata and help handler tests
 - [X] T005 Document fixture usage in `tests/fixtures/README.md` for module discovery tests
- [X] T029 [P] Add Pester test asserting mode detection (boxer vs box) occurs before discovery and selects correct module roots (FR-001)

**Checkpoint**: Foundation ready - user story work can begin.

---

## Phase 3: User Story 1 - Embedded Modules Maintain Current Behavior (Priority: P1) 🎯 MVP

**Goal**: Garantir que les modules embarqués `Invoke-{Mode}-{Command}` fonctionnent comme avant.
**Independent Test**: Pester scenario "embedded fallback" passes when no external override.

### Tests
- [X] T006 [P] [US1] Add Pester test ensuring `Invoke-Boxer-Install` routes when no external override (`tests/test-module-discovery-v2.ps1`)
- [X] T007 [P] [US1] Add Pester test ensuring `Invoke-Box-Pkg` default/help still reachable without external overrides

### Implementation
- [X] T008 [US1] Preserve embedded registration in `boxing.ps1` `Register-EmbeddedCommands` after routing changes

**Checkpoint**: Embedded commands operate unchanged.

---

## Phase 4: User Story 2 - External Modules Support Simplified V2 Architecture (Priority: P1)

**Goal**: Exécuter les modules externes (fichier ou dossier) sans wrapper de fonction, avec priorité sur embarqué.
**Independent Test**: External single-file and directory modules run directly via Pester fixtures.

### Tests
- [ ] T009 [P] [US2] Pester test for external single-file command execution (`tests/test-module-discovery-v2.ps1`)
- [ ] T010 [P] [US2] Pester test for directory module default (`foo/foo.ps1`) and subcommand (`foo/bar.ps1`)
- [ ] T011 [P] [US2] Pester test confirming external override wins over embedded when names collide
- [X] T030 [P] [US2] Pester test verifying argument passthrough `@args` for embedded functions and external single-file/directory modules (FR-012)

### Implementation
- [ ] T012 [US2] Update `boxing.ps1` `Import-ModeModules` to route external single-file modules via direct script execution
- [ ] T013 [US2] Update `boxing.ps1` directory-module logic to execute `{module}/{subcommand}.ps1` and `{module}/{module}.ps1` as default
- [ ] T033 [US2] Ensure routing path preserves argument splatting unchanged for all external module executions (FR-012)

**Checkpoint**: External modules run without function wrappers and override embedded ones.

---

## Phase 5: User Story 3 - Metadata Modules Enable Advanced Routing (Priority: P2)

**Goal**: Support metadata-driven routing (handlers, dispatchers, hooks) per schema.
**Independent Test**: Metadata fixture routes via dispatcher and handler as declared.

### Tests
- [ ] T014 [P] [US3] Pester test validating metadata-required keys and dispatcher/handler exclusivity
- [ ] T015 [P] [US3] Pester test ensuring dispatcher receives `-CommandPath` and routes to handler from metadata fixture
- [X] T031 [P] [US3] Pester test ensuring metadata-defined `help.ps1` is invoked and can override default help output (FR-020)
- [X] T032 [P] [US3] Pester test verifying argument passthrough to metadata handlers/dispatchers remains intact (FR-012)

### Implementation
- [ ] T016 [US3] Enhance metadata validation in `boxing.ps1` shared-module loading to enforce schema rules (required keys, exclusivity, hooks optional)
- [ ] T017 [US3] Adjust metadata execution path in `boxing.ps1` to honor dispatcher vs subcommand/handler selections
- [X] T034 [US3] Implement metadata help handler invocation when `help.ps1` exists and fallback when absent

**Checkpoint**: Metadata modules load and route correctly with validation errors reported gracefully.

---

## Phase 6: User Story 4 - Build Process Transforms Only Embedded Modules (Priority: P1)

**Goal**: Scripts de build enveloppent uniquement les modules embarqués en fonctions, aide préservée.
**Independent Test**: Build outputs contain `Invoke-{Mode}-{Command}` functions and embedded flags.

### Tests
- [ ] T018 [P] [US4] Add Pester/smoke check to run `scripts/build-boxer.ps1` and assert function wrappers & `$script:IsEmbedded` present in `dist/boxer.ps1`
- [ ] T019 [P] [US4] Add Pester/smoke check to run `scripts/build-box.ps1` and assert wrappers, shared pkg inclusion, and help preserved in `dist/box.ps1`

### Implementation
- [ ] T020 [US4] Align `scripts/build-boxer.ps1` wrapping logic with v2 (only modules/boxer, preserve comment help, version replacement)
- [ ] T021 [P] [US4] Align `scripts/build-box.ps1` wrapping logic with v2 (modules/box + shared/pkg, preserve help, embedded flags)

**Checkpoint**: Build artifacts match v2 expectations.

---

## Phase 7: User Story 5 - Runtime Discovery Supports Both Module Types (Priority: P1)

**Goal**: `boxing.ps1` découvre et route correctement fonctions embarquées et scripts externes avec priorité et aide.
**Independent Test**: Mixed scenarios (external override, embedded fallback, metadata dispatcher) all pass.

### Tests
- [ ] T022 [P] [US5] Pester test verifying mixed priority: external overrides embedded; embedded used when no external
- [X] T023 [P] [US5] Pester test ensuring `help` output lists sources and handles default-command/help cases for directory modules
- [X] T035 [P] [US5] Pester test covering help listing when a directory module lacks default command, ensuring subcommands are shown (FR-021)

### Implementation
- [ ] T024 [US5] Refactor `boxing.ps1` dispatcher to unify resolution: build command map with priority (external > embedded), support help indicators, forward args unchanged
- [ ] T025 [US5] Ensure dispatcher path passes `-CommandPath` to custom dispatchers and supports default command fallback when no subcommand
- [X] T036 [US5] Implement help path to list subcommands when no default exists for directory modules (aligned with FR-021)
- [X] T037 [US5] Harden mode detection to select boxer/box module roots before discovery and expose mode flag for downstream routing (FR-001)

**Checkpoint**: Runtime discovery conforms to v2 for all module types.

---

## Phase N: Polish & Cross-Cutting Concerns

- [ ] T026 [P] Update `quickstart.md` with any new test commands if routing changes impacted usage
- [ ] T027 Run full Pester suite `Invoke-Pester` from repo root and capture results in `tests/TEST-RESULTS-v2.txt`
- [ ] T028 Code cleanup: remove redundant routing code/comments in `boxing.ps1` post-refactor

---

## Dependencies & Execution Order

- Setup (Phase 1) → Foundational (Phase 2) → User Stories (Phases 3–7) → Polish (Phase N)
- All User Stories depend on Foundational completion.
- User Stories P1 (US1, US2, US4, US5) can proceed in parallel after Foundational; US3 (P2) can start after Foundational but may depend on US2 routing groundwork.
- Build tests (US4) should run after routing changes (US2/US5) are stabilized to avoid false negatives.

## Parallel Execution Examples

- External module tests (T009–T011) can run in parallel with metadata tests (T014–T015) once fixtures exist.
- Build checks (T018, T019) can run in parallel after routing refactor merges.
- Documentation polish (T026) can run in parallel with final Pester sweep (T027).

## Implementation Strategy

- **MVP**: Complete US1 + US2 + US5 to ensure runtime compatibility and external support, then US4 build alignment.
- **Incremental**: Finish Setup/Foundational → US1/US2/US5 in parallel → US4 build → US3 metadata validation → Polish.
- **Validation**: After each story, run targeted Pester blocks; finish with full `Invoke-Pester` and manual CLI checks from quickstart.
