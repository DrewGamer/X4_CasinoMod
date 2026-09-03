# X4 Foundations Casino Mod XP State (B4 Plan Memento)

## 1. Project Context
**Project Name:** X4 Foundations Casino Mod (`x4_casino_mod`)
**Project Type:** Game Mod
**Current Stage:** Phase 1 - Architecture Approval Gate (Blueprint v4 - Table Dealer Direct Hooking, Standalone Widget Updates & Immersion Polish)
**Active Branch:** `feat/station-physical-interaction` (Commit `aeab2c4`)
**Primary Tech Stack:**
- **Game Engine Target:** X4: Foundations (Egosoft)
- **Scripting & Logic:** Lua 5.1 / LuaJIT (Game UI & Core Logic), XML / Mission Director (Game Quests, NPC interactions, Cues)
- **Framework Dependencies:** kuertee UI Extensions and HUD (Nexus Mod 552), SirNukes Mod Support APIs (Simple Menu API)
- **Tooling / TDD:** Local Python venv (`lxml`, `xmlschema`), Local Lua runtime (`luaunit`, `luacheck`), Egosoft XSD Schemas (`schemas/`)
- **Automation:** PowerShell build & test scripts (`scripts/test.ps1`, `scripts/build.ps1`, `scripts/deploy_local.ps1`)

## 2. Active Goal & Constraints (B8 Attention Anchor)
**Current Objective:** Package and verify continuous build for station interior direct 'F' interactions, game lobby, and multi-game dispatcher (`T8`).
**Hard Constraints:**
- MUST pass human checkpoint for architecture approval before starting implementation.
- MUST pass human checkpoint for branch selection and PR reviews.
- MUST use `environment-manager` with human authorization for any new dependencies or tool installations.
- MUST prefer local project installs (`.venv/`, `.tools/`) over global machine installs. Zero global pollution.
- MUST keep all project artifacts, portable tools, and schemas within `C:\Projects\X4_CasinoMod`.
- MUST enforce Test-Driven Development (TDD) for any game logic before UI/MD integration.
- MUST isolate pure Lua core domain logic from X4 engine APIs to enable sub-second headless unit testing via `luaunit`.
- MUST validate all XML scripts against Egosoft XSD schemas (`md.xsd`, `content.xsd`) during local test runs.
- MUST produce a releasable archive at `dist/x4_casino_mod.zip` via `scripts/build.ps1` for `release-packager` and GitHub releases.
- MUST maintain `CHANGELOG.md` adhering to Keep a Changelog and Semantic Versioning.

## 3. Architecture & Tooling
**Approved Architecture:**
Three-tier decoupled mod architecture centered around the vanilla **Casino** and **Gambling Den** station modules (see [.agents/plans/archive/environment-setup-plan.md](file:///C:/Projects/X4_CasinoMod/.agents/plans/archive/environment-setup-plan.md)):
1. **Core Domain Layer (`lua/casino_core/`)**: Pure Lua 5.1 business logic (game registry, slot reel strips, RNG state machines, credit ledger, payout calculations). 100% unit-tested with `luaunit`.
2. **UI Adapter Layer (`ui/addons/x4_casino_mod/`)**: Lua UI extensions integrating with kuertee UI Extensions (Nexus 552) and SirNukes Simple Menu API for rendering interactive 2D table overlays, slot displays, betting controls, and central Game Lobby.
3. **Mission Director & Game Integration Layer (`md/`, `t/`, `content.xml`)**:
   - Direct 'F' interaction cues on room terminals (instant game launch) and Casino Host/Bartender NPCs (Game Lobby).
   - Closed-loop player station economics with solvency checks, graceful treasury drain, and Owner Free-Play mode.
   - Station Economy & "The House" mechanic: Player-owned casinos generate station revenue from NPC visitors, while playing at NPC casinos pays the local faction.

**Dependencies / Frameworks / Tools:**
- **Required In-Game Mods:**
  - `kuertee_ui_extensions` (Nexus Mod 552)
  - `sirnukes_mod_support_apis` (Nexus Mod 503 / Steam 2042901274)
- **Required Local Dev Tools (supervised via `environment-manager`):**
  - Git & GitHub CLI (`gh`) - Host verified
  - Python 3.10+ (Host or portable) + virtualenv (`lxml`, `xmlschema`)
  - Lua 5.1 / LuaJIT local binary (`.tools/lua/lua.exe`) + `luaunit.lua` + `luacheck.exe`
  - Egosoft X4 XSD Schemas (`schemas/*.xsd`)
  - Egosoft Catalog Tool (`XRcatTool.exe`) or Python catalog tool

**Version Mapping Convention:**
- `content.xml`: `version="020"` (X4 integer format)
- Git Tag / GitHub Release: `v0.2.0-beta` (SemVer 2.0.0)
- `CHANGELOG.md`: Tracks `## [Unreleased]` -> `## [v0.2.0-beta]`

**Build / Packaging Command:** `powershell -ExecutionPolicy Bypass -File scripts/build.ps1`
**Verification / Test Command:** `powershell -ExecutionPolicy Bypass -File scripts/test.ps1`

## 4. Work Backlog (B7 Todo Commands)
| ID | Title | Status | Assigned Persona | Dependencies |
|---|---|---|---|---|
| T0 | Environment Setup & Tooling Scaffolding Plan (XP Aligned) | done | xp-architect | - |
| T1 | Workflow Sync, Security Gate, Git Init & Workspace Layout (`.gitignore`, `CHANGELOG.md`, `.luacheckrc`, `.vscode`) | done | xp-developer | T0 |
| T2 | Local Python venv & XML Validator Pipeline Setup (`lxml`, `xmlschema`, `scripts/validate_xml.py`) | done | xp-developer | T1 |
| T3 | Local Lua Runtime, Linter, & Headless TDD Test Harness Setup (`luaunit`, `luacheck`, `scripts/test.ps1`) | done | xp-developer | T1 |
| T4 | Egosoft XSD Schemas & Mod Dependency Extraction (Nexus 552 & SirNukes APIs in `dependencies/`) | done | xp-developer | T2, T3 |
| T5 | Build & Local Deployment Automation Scripts (`scripts/build.ps1`, `scripts/deploy_local.ps1`) | done | xp-developer | T4 |
| T6 | Feature: 3-Reel Slots Core Engine TDD (Teladi Profit Spinner - PoC) | done | xp-developer | T3, T5 |
| T7 | Feature: SirNukes Simple Menu Adapter for 3-Reel Slots UI (PoC) | done | xp-developer | T6 |
| T8 | Feature: Station Physical Interaction & Multi-Game Dispatcher | done | xp-developer | T7 |
| T8.1 | Game Registry & Dispatcher Scaffolding (`lua/casino_core/game_registry.lua`, `tests/lua/test_game_registry.lua`) | done | xp-developer | T8 |
| T8.2 | MD Physical Room Detection & Direct Terminal Triggers (`md/CasinoStationCues.xml`) | done | xp-developer | T8.1 |
| T8.3 | Casino Host & Bar Lobby Direct Triggers (`md/CasinoStationCues.xml`) | done | xp-developer | T8.2 |
| T8.4 | Standalone Modal Menu Launcher & Game Lobby UI (`Simple_Menu_API.Create_Menu`) | done | xp-developer | T8.2 |
| T8.5 | Station Economy Ledger, Solvency Checks & Owner Free-Play (`$casino_data`, `$casino_ledger`) | done | xp-developer | T8.4 |
| T8.6 | End-to-End Test Suite, XML Schema Validation, & Dist Packaging | done | xp-developer | T8.5 |
| T8.7 | Dynamic Room & Dealer Tag Discovery Engine (Room Tags & Roulette Slot Discovery) | done | xp-developer | T8.6 |
| T8.8 | Vanilla Table Dealer Direct Bypass Cue (`$roulette_dealer_slot` / Frame 0 bypass) | done | xp-developer | T8.7 |
| T8.9 | Station Bartender Contextual Dialogue Hook (`entitytype.bartender` only) | done | xp-developer | T8.8 |
| T8.10 | Wandering NPC Dialogue Filter & Cleanup (Preserve 100% vanilla comms on crew) | done | xp-developer | T8.8, T8.9 |
| T8.11 | Transient Fallback Croupier Spawner & Despawn Guard (with room exit cleanup) | done | xp-developer | T8.7 |
| T8.12 | End-to-End Validation, Test Automation & Packaging | done | xp-developer | T8.7, T8.8, T8.9, T8.10, T8.11 |
| T8.13 | Slot Actor Direct Hooking & Busy Flag Suppression (`$slot.component.slotactor.{$slot}`, `busy="false"`) | pending | xp-developer | T8.12 |
| T8.14 | Standalone UI Live Widget Update Pipeline (`md.Simple_Menu_API.Update_Widget`) | pending | xp-developer | T8.13 |
| T8.15 | Savegame Schema Defense & Blackboard Null Migration (`not $JackpotsHit?`) | pending | xp-developer | T8.12 |
| T8.16 | ASCII Typography Sanitization (Eliminate `?` glyph rendering artifacts) | pending | xp-developer | T8.14 |
| T8.17 | Regression Verification & Continuous Re-Packaging (`scripts/test.ps1`, `scripts/build.ps1`) | pending | xp-developer | T8.13, T8.14, T8.15, T8.16 |

## 5. Sub-Agent Coordination
- **Phase 0 & 1**: Architectural Blueprint v3 developed by `xp-architect` in [.agents/plans/station-interior-interaction-architecture.md](file:///C:/Projects/X4_CasinoMod/.agents/plans/station-interior-interaction-architecture.md) addressing pure physical immersion, static dealer bypass, bartender dialogue hooks, and crew clutter elimination.
- **Phase 2 Execution**: `xp-developer` completed tasks `T8.7` through `T8.12` on feature branch `feat/station-physical-interaction`.
- **Phase 3 Continuous Packaging**: `release-packager` will bundle `dist/x4_casino_mod.zip` and publish to GitHub tag `continuous-build`.
- **Phase 4 Manual Checkpoint**: Human manual verification of test suite & built artifact.
- **Phase 5 Release Gate**: PR creation via `gh pr create`, merge to `main`, `CHANGELOG.md` stamp, and SemVer release creation (`v0.2.0-beta`).

## 6. Checkpoints & History
- [x] Environment Scaffolding Plan Drafted & XP-Aligned
- [x] POC Game Selected: 3-Reel Slot Machine ("Teladi Profit Spinner")
- [x] Phase 1 Architecture Approval (Human Checkpoint)
- [x] Environment Setup Implemented & Verified (T1–T5)
- [x] 3-Reel Slots TDD Core Complete (T6)
- [x] Phase 3 Continuous Build Packaged & Uploaded (`dist/x4_casino_mod.zip`)
- [x] Phase 4 Manual Verification Passed
- [x] Phase 5 Released & Tagged (`v0.1.0-beta`)
- [x] Phase 2 Station Physical Interactions Initial Implementation (T8.1–T8.6)
- [x] Phase 1 Architecture Blueprint v3 Approval (Static Dealer Hooking & Conversation Bypass)
- [x] Phase 2 Station Physical Immersion Implementation Complete (T8.7–T8.12)

## 7. Release Configuration
**Continuous Release Tag:** continuous-build
**Continuous Release Name:** Continuous Build
**Target Output Artifact:** dist/x4_casino_mod.zip
**SemVer Target Tag:** v0.1.0-beta
**Build Type Override:** 

