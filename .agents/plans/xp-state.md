# X4 Foundations Casino Mod XP State (B4 Plan Memento)

## 1. Project Context
**Project Name:** X4 Foundations Casino Mod (`x4_casino_mod`)
**Project Type:** Game Mod
**Current Stage:** Phase 4 - Manual Testing Loop (Scaffolding & Slots PoC)
**Active Branch:** `feat/scaffolding-and-slots-poc`
**Primary Tech Stack:**
- **Game Engine Target:** X4: Foundations (Egosoft)
- **Scripting & Logic:** Lua 5.1 / LuaJIT (Game UI & Core Logic), XML / Mission Director (Game Quests, NPC interactions, Cues)
- **Framework Dependencies:** kuertee UI Extensions and HUD (Nexus Mod 552), SirNukes Mod Support APIs (Simple Menu API)
- **Tooling / TDD:** Local Python venv (`lxml`, `xmlschema`), Local Lua runtime (`luaunit`, `luacheck`), Egosoft XSD Schemas (`schemas/`)
- **Automation:** PowerShell build & test scripts (`scripts/test.ps1`, `scripts/build.ps1`, `scripts/deploy_local.ps1`)

## 2. Active Goal & Constraints (B8 Attention Anchor)
**Current Objective:** Human manual verification of test suite (`scripts/test.ps1`) and continuous build artifact (`dist/x4_casino_mod.zip`) before Phase 5 PR creation and release tagging.
**Hard Constraints:**
- MUST pass human checkpoint for architecture approval before starting T1. (APPROVED)
- MUST pass human checkpoint for branch selection and PR reviews.
- MUST use `environment-manager` with human authorization for any new dependencies or tool installations.
- MUST prefer local project installs (`.venv/`, `.tools/`) over global machine installs. Zero global pollution.
- MUST keep all project artifacts, portable tools, and schemas within `C:\Projects\X4_CasinoMod`.
- MUST enforce Test-Driven Development (TDD) for all casino game logic (Blackjack, Roulette, Slots, Craps) before UI/MD integration.
- MUST isolate pure Lua core domain logic from X4 engine APIs to enable sub-second headless unit testing via `luaunit`.
- MUST validate all XML scripts against Egosoft XSD schemas (`md.xsd`, `content.xsd`) during local test runs.
- MUST produce a releasable archive at `dist/x4_casino_mod.zip` via `scripts/build.ps1` for `release-packager` and GitHub releases.
- MUST maintain `CHANGELOG.md` adhering to Keep a Changelog and Semantic Versioning.

## 3. Architecture & Tooling
**Approved Architecture:**
Three-tier decoupled mod architecture centered around the vanilla **Casino** and **Gambling Den** station modules (see [.agents/plans/archive/environment-setup-plan.md](file:///C:/Projects/X4_CasinoMod/.agents/plans/archive/environment-setup-plan.md)):
1. **Core Domain Layer (`lua/casino_core/`)**: Pure Lua 5.1 business logic (card decks, hand evaluators, roulette payout math, RNG state machines, slot reel strips, credit ledger, house edge/rake calculations). 100% unit-tested with `luaunit`.
2. **UI Adapter Layer (`ui/addons/x4_casino_mod/`)**: Lua UI extensions integrating with kuertee UI Extensions (Nexus 552) and SirNukes Simple Menu API for rendering interactive 2D table overlays, slot displays, and betting controls.
3. **Mission Director & Game Integration Layer (`md/`, `t/`, `content.xml`)**:
   - Hooks into the vanilla **Casino** and **Gambling Den** interior rooms (and standard Station Bars as a fallback).
   - Enables physical `F` interaction on gaming tables, terminals, and croupier NPCs inside casino rooms (zero comms menu clutter).
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
- `content.xml`: `version="010"` (X4 integer format)
- Git Tag / GitHub Release: `v0.1.0-beta` (SemVer 2.0.0)
- `CHANGELOG.md`: Tracks `## [Unreleased]` -> `## [v0.1.0-beta]`

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
| T8 | Feature: Station Casino & Bar Physical 'F' Interaction Cues (`md/CasinoStationCues.xml`) | done | xp-developer | T7 |
| T9 | Feature: Card Deck Core & Blackjack TDD Implementation (Iteration 2) | pending | xp-developer | T6, T8 |

## 5. Sub-Agent Coordination
- **Phase 0 & 1**: Plan updated by `xp-architect` and submitted for human checkpoint review.
- **Phase 2 Execution**: `xp-developer` executed tasks `T1` through `T6` sequentially on feature branch `feat/scaffolding-and-slots-poc`.
- **Phase 3 Continuous Packaging**: `release-packager` will bundle `dist/x4_casino_mod.zip` and publish to GitHub tag `continuous-build`.
- **Phase 4 Manual Checkpoint**: Human manual verification of test suite & built artifact.
- **Phase 5 Release Gate**: PR creation via `gh pr create`, merge to `main`, `CHANGELOG.md` stamp, and SemVer release creation (`v0.1.0-beta`).

## 6. Checkpoints & History
- [x] Environment Scaffolding Plan Drafted & XP-Aligned
- [x] POC Game Selected: 3-Reel Slot Machine ("Teladi Profit Spinner")
- [x] Phase 1 Architecture Approval (Human Checkpoint)
- [x] Environment Setup Implemented & Verified (T1–T5)
- [x] 3-Reel Slots TDD Core Complete (T6)
- [x] Phase 3 Continuous Build Packaged & Uploaded (`dist/x4_casino_mod.zip`)
- [x] Phase 4 Manual Verification Passed
- [x] Phase 5 Released & Tagged (`v0.1.0-beta`)

## 7. Release Configuration
**Continuous Release Tag:** continuous-build
**Continuous Release Name:** Continuous Build
**Target Output Artifact:** dist/x4_casino_mod.zip
**SemVer Target Tag:** v0.1.0-beta
**Build Type Override:** 

