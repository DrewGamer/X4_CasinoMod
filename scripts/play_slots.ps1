# PowerShell launcher for interactive terminal slots game

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$luaExe = Join-Path $projectRoot ".tools\lua\lua.exe"
$gameScript = Join-Path $scriptDir "play_slots.lua"

if (-not (Test-Path $luaExe)) {
    Write-Host "[-] Lua runtime not found at $luaExe" -ForegroundColor Red
    exit 1
}

& $luaExe $gameScript
