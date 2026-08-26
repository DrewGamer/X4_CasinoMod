# X4 Foundations Casino Mod (`x4_casino_mod`)

An interactive casino gambling mod for **X4: Foundations**, featuring 3-Reel Slot Machines ("Teladi Profit Spinner"), Blackjack, Roulette, Craps, and full station economy integration.

## Mod Features
- **Station Casino & Bar Integration**: Physical `F` interactions at tables and terminals in station casino modules and bars.
- **Pure Lua Domain Core**: Decoupled, deterministic game rules and payout logic built with strict Test-Driven Development (TDD).
- **Sub-Second Test Pipeline**: Complete headless unit testing and schema validation runnable in <2s without launching the game.

## Requirements
- **X4: Foundations** (v7.x+ recommended)
- **kuertee UI Extensions and HUD** (Nexus Mod 552)
- **SirNukes Mod Support APIs** (Nexus Mod 503 / Steam 2042901274)

## Development & Testing
- Run test suite: `powershell -ExecutionPolicy Bypass -File scripts/test.ps1`
- Build distribution package: `powershell -ExecutionPolicy Bypass -File scripts/build.ps1`
- Local deployment: `powershell -ExecutionPolicy Bypass -File scripts/deploy_local.ps1`
