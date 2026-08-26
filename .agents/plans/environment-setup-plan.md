# Environment Setup & Tooling Scaffolding Plan: X4 Foundations Casino Mod

## 1. Overview & Architectural Goals

The **X4 Foundations Casino Mod** (`x4_casino_mod`) introduces interactive casino gambling mini-games (e.g., 3-Reel Slots, Blackjack, Roulette, Craps) into *X4: Foundations*.

To adhere to **Extreme Programming (XP)** and **Test-Driven Development (TDD)** managed by the [xp-orchestrator](file:///C:/Projects/X4_CasinoMod/.agents/skills/xp-orchestrator/SKILL.md) lifecycle, development is decoupled into three distinct architectural tiers:

1. **Core Domain Layer (`lua/casino_core/`)**: Pure Lua 5.1 business logic (card decks, hand evaluators, betting math, RNG state machines, slot reel strips, credit ledger, house edge/rake calculations). **Zero X4 engine dependencies**, enabling 100% automated headless unit testing via `luaunit`.
2. **UI & View Adapter Layer (`ui/addons/x4_casino_mod/`)**: Lua UI extensions integrating with **kuertee UI Extensions and HUD** (Nexus Mod 552) and **SirNukes Mod Support APIs** (Simple Menu API) to render interactive 2D table overlays, slot displays, and betting dialogs.
3. **Mission Director & Game Integration Layer (`md/`, `t/`, `content.xml`)**: XML scripts and cues handling station casino room (`Casino` / `Gambling Den`) triggers, physical `F` interactions on tables/terminals, NPC croupiers, docking cues, and player credit transactions (`<reward_player>` / `<sub_money>`).

### XP Workflow & Tooling Constraints
- **Agent XP Lifecycle Compliance**: All work is orchestrated via [xp-orchestrator](file:///C:/Projects/X4_CasinoMod/.agents/skills/xp-orchestrator/SKILL.md) through assigned personas ([xp-architect](file:///C:/Projects/X4_CasinoMod/.agents/personas/xp-architect.md), [xp-developer](file:///C:/Projects/X4_CasinoMod/.agents/personas/xp-developer.md)) with explicit gates via [human-checkpoint](file:///C:/Projects/X4_CasinoMod/.agents/skills/human-checkpoint/SKILL.md).
- **Supervised Tool Acquisition**: Missing dependencies are acquired exclusively via [environment-manager](file:///C:/Projects/X4_CasinoMod/.agents/skills/environment-manager/SKILL.md) after explicit human approval.
- **Local-First Tooling**: Compilers, linters, schemas, and virtual environments reside within `C:\Projects\X4_CasinoMod` (`.venv/`, `.tools/`, `schemas/`). Zero global pollution.
- **Sub-Second Test Feedback**: Running `scripts/test.ps1` executes all unit tests, Luacheck linting, and XML validations in under 2 seconds without launching the game.
- **Fail-Fast XML Validation**: XML diffs and Mission Director scripts are validated against official Egosoft XSD schemas before packaging.
- **Deterministic Release Packaging**: `scripts/build.ps1` produces a clean, releasable archive at `dist/x4_casino_mod.zip` ready for continuous builds (`continuous-build` tag via `release-packager`) and GitHub SemVer releases (`v0.1.0-beta`).
- **Version Mapping**:
  - **Egosoft XML Version** in `content.xml`: `version="010"` (integer representation of 0.10)
  - **GitHub Release / Git Tag**: `v0.1.0-beta` (SemVer 2.0.0 format)
  - **Changelog**: Maintained at `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## 2. Target Workspace Layout

```text
C:\Projects\X4_CasinoMod\
├── .agents/                      # Agent XP lifecycle framework
│   ├── hooks.json                # PreToolUse security & streamline hook
│   ├── personas/                 # xp-architect, xp-developer
│   ├── plans/
│   │   ├── xp-state.md           # XP state memento
│   │   └── environment-setup-plan.md # Architectural blueprint
│   ├── scripts/                  # sync_workflow.ps1, security_gate.ps1, security_gate.template.ps1
│   └── skills/                   # xp-orchestrator, environment-manager, human-checkpoint, release-packager, genesis
├── .tools/                       # Local portable binaries (git-ignored)
│   ├── lua/                      # Portable Lua 5.1 / LuaJIT binary & DLLs, luacheck.exe
│   └── egosoft/                  # XRcatTool.exe / Catalog packager
├── .venv/                        # Local Python 3 virtual environment (git-ignored)
├── .vscode/                      # VS Code workspace settings & schema bindings
│   ├── settings.json
│   └── tasks.json
├── CHANGELOG.md                  # Semantic changelog following Keep a Changelog
├── config.local.json.template    # Template for local X4 installation paths
├── dependencies/                 # Reference copies / API headers of required mods
│   ├── kuertee_ui_extensions/    # Nexus Mod 552 reference/mocks
│   └── sirnukes_mod_support/     # SirNukes APIs reference/mocks
├── dist/                         # Packaged mod output & release zip (git-ignored)
│   ├── x4_casino_mod/            # Uncompressed directory structure
│   └── x4_casino_mod.zip         # Packaged archive for GitHub Releases
├── lua/
│   ├── casino_core/              # Pure Lua 5.1 core game domain (TDD)
│   │   ├── blackjack.lua
│   │   ├── roulette.lua
│   │   ├── slots.lua
│   │   └── deck.lua
│   └── ui_adapters/              # UI glue code for kuertee / SirNukes APIs
├── md/                           # Mission Director XML scripts
│   └── CasinoStationCues.xml
├── schemas/                      # Egosoft XSD schemas for XML validation (git-tracked)
│   ├── md.xsd
│   ├── aiscripts.xsd
│   ├── content.xsd
│   └── libraries.xsd
├── scripts/                      # PowerShell & Python automation scripts
│   ├── test.ps1                  # Runs Lua unit tests + XML validation + Luacheck (< 2s)
│   ├── build.ps1                 # Packages mod into dist/x4_casino_mod/ and dist/x4_casino_mod.zip
│   ├── deploy_local.ps1          # Deploys/symlinks mod to local X4 game directory
│   └── validate_xml.py           # Python XML Schema (XSD) & diff validator
├── t/                            # Text localization files
│   └── 0001-l044.xml             # English text database (Page ID 998811)
├── tests/
│   ├── lua/                      # Lua unit test suite
│   │   ├── luaunit.lua           # Standalone pure-Lua test framework
│   │   ├── test_deck.lua
│   │   ├── test_blackjack.lua
│   │   └── test_slots.lua
│   └── mocks/                    # Mocked X4 Lua globals (Helper, AddMenuRow, etc.)
│       └── x4_engine_mock.lua
├── ui/
│   └── addons/
│       └── x4_casino_mod/        # In-game Lua UI add-on files
├── .gitignore
├── .luacheckrc                   # Luacheck config with X4 globals whitelisted
├── content.xml                   # X4 Mod metadata and dependencies manifest
└── README.md
```

---

## 3. Required Tools & Local Acquisition Strategy

All missing tools must be acquired using the [environment-manager](file:///C:/Projects/X4_CasinoMod/.agents/skills/environment-manager/SKILL.md) supervised execution pattern with explicit [human-checkpoint](file:///C:/Projects/X4_CasinoMod/.agents/skills/human-checkpoint/SKILL.md) gates.

| Tool | Purpose | Acquisition Method via `environment-manager` | Local Target Path |
|---|---|---|---|
| **Git** | Version control & XP workflow | System-installed (Git 2.54 verified) | Host PATH |
| **GitHub CLI (`gh`)** | PR creation, continuous build uploads & releases | System-installed (gh 2.92.0 verified) | Host PATH |
| **Python 3.10+** | XML validation, build tooling, virtualenv | Acquire via `winget install Python.Python.3.12` (prompting human authorization) | Host PATH / `.venv/` |
| **Python `lxml` & `xmlschema`** | Strict XSD validation of Mission Director XML & diffs | `pip install lxml xmlschema` inside `.venv` | `.venv/Lib/site-packages` |
| **Lua 5.1 / LuaJIT** | Local runtime for unit tests & TDD | Download portable Windows Lua 5.1 binary to `.tools/lua/lua.exe` | `.tools/lua/lua.exe` |
| **LuaUnit** | Unit testing framework (pure Lua) | Download single-file `luaunit.lua` | `tests/lua/luaunit.lua` |
| **Luacheck** | Static analysis & linting for Lua | Download standalone binary / npm bundle into `.tools/lua/` | `.tools/lua/luacheck.exe` |
| **Egosoft XSD Schemas** | Schema definitions for X4 XML files | Extract or fetch from official Egosoft tools/repo | `schemas/*.xsd` |
| **XRcatTool / CatPack** | `.cat`/`.dat` archive creation & extraction | Egosoft official tool or Python `x4customizer` | `.tools/egosoft/XRcatTool.exe` |

---

## 4. Step-by-Step Implementation Instructions for XP Developer

Tasks below correspond directly to backlog items `T1` through `T6` in [.agents/plans/xp-state.md](file:///C:/Projects/X4_CasinoMod/.agents/plans/xp-state.md).

### Step 1: Workflow Sync, Security Gate & Workspace Scaffolding (`T1`)
1. Sync & update the Agent XP workflow:
   - Run `powershell -ExecutionPolicy Bypass -File .agents/scripts/sync_workflow.ps1` to pull the latest skills, personas, hooks, and templates.
2. Configure Security & Streamline Gate:
   - Verify `.agents/hooks.json` points to `.agents/scripts/security_gate.ps1`.
   - Ensure `.agents/scripts/security_gate.ps1` auto-approves safe project toolchains (`.venv/Scripts/python`, `.tools/lua/lua.exe`, `scripts/*.ps1`, `git init`, `schemas/`) while protecting workspace boundaries and PR merge gates.
3. Initialize git repository: `git init` in `C:\Projects\X4_CasinoMod`.
4. Create initial feature branch for scaffolding: `git checkout -b feat/scaffolding-and-slots-poc`.
5. Create `.gitignore`:
   ```gitignore
   # Local tools & virtual environment
   .venv/
   .tools/
   *.pyc
   __pycache__/

   # Build & distribution artifacts
   dist/
   build/
   *.cat
   *.dat
   *.zip

   # Local user configuration & CLI caches
   config.local.json
   local.properties
   .antigravitycli/

   # IDE and OS
   .DS_Store
   Thumbs.db
   .idea/
   ```
6. Create initial `CHANGELOG.md` adhering to Keep a Changelog / SemVer:
   ```markdown
   # Changelog

   All notable changes to this project will be documented in this file.

   The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
   and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

   ## [Unreleased]
   ### Added
   - Initial repository scaffolding, local tooling, and TDD test harness.
   ```
5. Create `.luacheckrc` with X4 and UI Extensions globals:
   ```lua
   -- .luacheckrc
   std = "lua51"
   globals = {
       "Helper", "AddMenuRow", "CreateMenu", "GetPlayerMoney", "AddPlayerMoney",
       "C", "ffi", "DebugError", "GetComponentData", "GetUserData", "OpenMenu",
       "CloseMenu", "RegisterEvent", "AddUITrigger", "Menus", "Lib", "Config"
   }
   max_line_length = 120
   ```
6. Create `.vscode/settings.json`:
   ```json
   {
       "files.eol": "\n",
       "xml.validation.enabled": true,
       "xml.fileAssociations": [
           {
               "pattern": "md/*.xml",
               "systemId": "schemas/md.xsd"
           },
           {
               "pattern": "content.xml",
               "systemId": "schemas/content.xsd"
           }
       ]
   }
   ```
7. Create `config.local.json.template`:
   ```json
   {
       "x4_install_path": "C:/Program Files (x86)/Steam/steamapps/common/X4 Foundations",
       "x4_user_extensions_path": "C:/Users/USERNAME/Documents/Egosoft/X4/USERID/extensions",
       "deploy_mode": "symlink"
   }
   ```

### Step 2: Python Environment & XML Validation Suite Setup (`T2`)
1. Verify Python 3.10+ availability:
   - If missing, invoke [environment-manager](file:///C:/Projects/X4_CasinoMod/.agents/skills/environment-manager/SKILL.md) & [human-checkpoint](file:///C:/Projects/X4_CasinoMod/.agents/skills/human-checkpoint/SKILL.md) to install Python 3.12 via `winget install Python.Python.3.12 -h --accept-package-agreements --accept-source-agreements`.
2. Create project-local virtual environment:
   ```powershell
   python -m venv .venv
   ```
3. Install required validation libraries:
   ```powershell
   & .\.venv\Scripts\pip.exe install lxml xmlschema
   ```
4. Create `scripts/validate_xml.py`:
   - Validates all `.xml` files in `md/`, `t/`, and root `content.xml` against schemas in `schemas/`.
   - Validates XML syntax and diff node syntax (`<diff><add>`, `<replace>`, `<remove>`).
   - Exits with `0` on success, `1` on validation errors with detailed line numbers.

### Step 3: Local Lua Runtime, LuaUnit, and Luacheck Setup (`T3`)
1. Acquire portable Lua 5.1 / LuaJIT executable into `.tools/lua/lua.exe` via [environment-manager](file:///C:/Projects/X4_CasinoMod/.agents/skills/environment-manager/SKILL.md).
   - Verification: `& .\.tools\lua\lua.exe -v` outputs `Lua 5.1.x` or `LuaJIT 2.x`.
2. Acquire standalone `luaunit.lua` into `tests/lua/luaunit.lua`.
3. Acquire standalone `luacheck` executable into `.tools/lua/luacheck.exe`.
4. Create `tests/mocks/x4_engine_mock.lua`:
   - Mocks X4 engine functions (`GetPlayerMoney`, `AddPlayerMoney`, `AddUITrigger`, `Helper`) so UI adapters can be tested headlessly.

### Step 4: Mod Dependencies & Egosoft Schemas (`T4`)
1. Populate official Egosoft XSD schemas (`md.xsd`, `content.xsd`, `aiscripts.xsd`, `libraries.xsd`) into `schemas/`.
2. Set up `dependencies/` folder for API documentation and mocking:
   - **kuertee UI Extensions and HUD (Nexus Mod 552)**
   - **SirNukes Mod Support APIs (Simple Menu API)**
3. Create standard `content.xml` manifest:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <content id="x4_casino_mod" name="X4 Casino Mod" version="010" sync="false"
            description="Adds interactive casino gambling games (Blackjack, Roulette, Slots) to station lounges and bars."
            author="ModAuthor">
       <dependency id="kuertee_ui_extensions" optional="false" name="UI Extensions and HUD"/>
       <dependency id="sirnukes_mod_support_apis" optional="true" name="SirNukes Mod Support APIs"/>
   </content>
   ```

### Step 5: PowerShell Automation Scripts (`T5`)
1. Create `scripts/test.ps1`:
   - Runs `scripts/validate_xml.py` using `.venv\Scripts\python.exe`.
   - Runs `luacheck` against all files in `lua/`, `ui/`, and `tests/`.
   - Runs `luaunit` test suites in `tests/lua/test_*.lua` using `.tools\lua\lua.exe`.
   - Returns exit code 0 on full success, non-zero on any failure. Total execution time must be under 2 seconds.
2. Create `scripts/build.ps1` (Compliant with [release-packager](file:///C:/Projects/X4_CasinoMod/.agents/skills/release-packager/SKILL.md)):
   - Runs `scripts/test.ps1` to ensure tests and linting pass before bundling.
   - Cleans and creates `dist/x4_casino_mod/`.
   - Copies production assets (`content.xml`, `md/`, `t/`, `ui/`, `lua/`) into `dist/x4_casino_mod/`.
   - Strips development files (`tests/`, `.tools/`, `.venv/`, `.agents/`, `.vscode/`).
   - Compresses `dist/x4_casino_mod/` into `dist/x4_casino_mod.zip` for [release-packager](file:///C:/Projects/X4_CasinoMod/.agents/skills/release-packager/SKILL.md) and GitHub Releases.
3. Create `scripts/deploy_local.ps1`:
   - Reads `config.local.json`.
   - Creates a symbolic link or directory copy from `dist/x4_casino_mod` to the user's X4 `extensions/x4_casino_mod` folder for immediate in-game testing.

### Step 6: TDD Smoke Test Verification: 3-Reel Slots PoC (`T6`)
1. Create initial test file `tests/lua/test_slots.lua`:
   - Tests 3-reel strip initialization with standard X4 symbols (`"energy_cells"`, `"ore"`, `"silicon"`, `"nividium"`, `"teladi_profit"`).
   - Tests deterministic RNG spin resolution using a seeded PRNG.
   - Tests paytable evaluation logic:
     - 3x `"teladi_profit"` = Jackpot (50x payout)
     - 3x `"nividium"` = Major Win (20x payout)
     - 3x `"ore"` / `"silicon"` = Medium Win (10x payout)
     - 2x any matching = Minor Win (2x payout)
     - No match = Loss (0x payout)
2. Create initial domain file `lua/casino_core/slots.lua`:
   - Implement the pure-Lua slots state machine and paytable engine to make `test_slots.lua` pass.
3. Run `pwsh ./scripts/test.ps1` and verify:
   - XML validation passes against Egosoft schemas.
   - Luacheck linter passes with 0 warnings.
   - LuaUnit runs 100% passing tests for the 3-Reel Slots engine.

---

## 5. Acceptance Checklist & XP Milestones

- [ ] **T1 Scaffolding**: Workflow synced (`sync_workflow.ps1`), security gate configured (`hooks.json` & `security_gate.ps1`), Git initialized, branch `feat/scaffolding-and-slots-poc` created, `.gitignore`, `CHANGELOG.md`, `.luacheckrc`, `.vscode/` configured.
- [ ] **T2 Python & XML Validator**: `.venv/` created with `lxml`/`xmlschema`, `scripts/validate_xml.py` working.
- [ ] **T3 Lua Runtime & Harness**: `.tools/lua/lua.exe` installed (`lua -v`), `tests/lua/luaunit.lua` installed, `luacheck.exe` configured.
- [ ] **T4 Schemas & Dependencies**: `schemas/` populated with Egosoft XSDs, `content.xml` validated.
- [ ] **T5 Automation Scripts**: `scripts/test.ps1` (<2s), `scripts/build.ps1` generates `dist/x4_casino_mod.zip`, `scripts/deploy_local.ps1` ready.
- [ ] **T6 Slots Engine PoC**: `lua/casino_core/slots.lua` passing 100% tests in `tests/lua/test_slots.lua`.
- [ ] **XP Phase 3 Continuous Release**: [release-packager](file:///C:/Projects/X4_CasinoMod/.agents/skills/release-packager/SKILL.md) generates build and uploads `dist/x4_casino_mod.zip` to tag `continuous-build`.
- [ ] **XP Phase 4 Manual Checkpoint**: Human verification of the test suite and build output before proceeding to UI integration (`T7`).
