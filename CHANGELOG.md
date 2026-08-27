# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Planned
- Interactive physical terminal and room interaction for slot machines in station casino modules and bars (Task T8).

## [v0.1.0-beta] - 2026-08-26
### Added
- **Pure-Lua Domain Layer**: `lua/casino_core/slots.lua` implementing the 3-Reel Slots engine ("Teladi Profit Spinner").
- **Headless TDD Test Suite**: Sub-second test runner (`scripts/test.ps1`) with 18 automated unit tests via LuaUnit.
- **XML Schema Validation Suite**: Python validation tool (`scripts/validate_xml.py`) checking `content.xsd`, `md.xsd`, and `libraries.xsd`.
- **Static Analysis & Linting**: Complete `luacheck` configuration (`.luacheckrc`) with 0 warnings.
- **SirNukes Simple Menu Adapter**: In-game Extension Options menu interface in `md/CasinoStationCues.xml` with live credit transactions.
- **Build & Packaging Tooling**: Production packaging (`scripts/build.ps1`) and local X4 game deployment (`scripts/deploy_local.ps1`).
- **Interactive Terminal Simulator**: Headless CLI tool (`scripts/play_slots.ps1` / `scripts/play_slots.lua`) for Monte Carlo odds analysis outside the game.
