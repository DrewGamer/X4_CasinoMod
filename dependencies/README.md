# Mod Dependencies & Offline Reference Library

## Purpose of this Directory

This directory serves as a **local developer reference and API documentation store** for external third-party mods required or supported by the **X4 Casino Mod**.

### Key Uses:
1. **API Specifications & Documentation**: Offline reference for Lua API signatures, callback registrations, and Mission Director cue interfaces (e.g., SirNukes Simple Menu API, kuertee UI callback hooks) without needing active web lookups.
2. **Unit Test Mocking Reference**: Provides the exact schema and interface contracts used to author headless mocks in `tests/mocks/` (e.g. `x4_engine_mock.lua`).
3. **Local Inspection**: Allows inspecting original mod architectures, menu templates, and XML event definitions during development.

---

## Build & Repository Lifecycle Rules

- **Git Ignored**: This directory is listed in `.gitignore` to avoid checking third-party binary/source code into git history.
- **Excluded from Builds**: The build pipeline (`scripts/build.ps1`) ignores `dependencies/` and only packages first-party source files (`lua/`, `ui/`, `md/`, `t/`, `content.xml`) into `dist/x4_casino_mod.zip`.
- **Runtime Decoupling**: X4 loads dependencies independently from the player's `extensions/` directory based on the IDs declared in root `content.xml`.

---

## Subdirectories

| Subfolder | Mod Name | Source / ID | Primary Usage |
|---|---|---|---|
| `sn_mod_support_apis/` | **SirNukes Mod Support APIs** | Nexus Mod 503 / Steam 2042901274 (`ws_2042901274`) | Simple Menu API, Options Menu registration, Custom UI tables, Pipe APIs. Detailed documentation is in `sn_mod_support_apis/documentation/`. |
| `kuertee_ui_extensions/` | **kuertee UI Extensions and HUD** | Nexus Mod 552 (`kuerteeUIExtensionsAndHUD`) | UI menu patching and interaction hook callbacks without vanilla file conflicts. |
