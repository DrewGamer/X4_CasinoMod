# PowerShell Test Runner for X4 Casino Mod
# Runs XML validation, Luacheck linting, and LuaUnit test suite in <2 seconds.

[CmdletBinding()]
param (
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

$pythonExe = Join-Path $projectRoot ".venv\Scripts\python.exe"
$luaExe = Join-Path $projectRoot ".tools\lua\lua.exe"
$luacheckExe = Join-Path $projectRoot ".tools\lua\luacheck.exe"
$validatorScript = Join-Path $scriptDir "validate_xml.py"
$testsDir = Join-Path $projectRoot "tests\lua"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "X4 Casino Mod - XP Test & Validation Pipeline" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$startTime = [System.Diagnostics.Stopwatch]::StartNew()
$failed = $false

# 1. XML Schema & Syntax Validation
Write-Host "`n[1/3] Running XML & XSD Validation..." -ForegroundColor Yellow
if (Test-Path $pythonExe) {
    & $pythonExe $validatorScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[-] XML Validation FAILED!" -ForegroundColor Red
        $failed = $true
    } else {
        Write-Host "[+] XML Validation PASSED." -ForegroundColor Green
    }
} else {
    Write-Host "[!] Warning: Python virtualenv not found at $pythonExe. Skipping XML validation." -ForegroundColor Yellow
}

# 2. Lua Code Linting (Luacheck)
Write-Host "`n[2/3] Running Luacheck Static Analysis..." -ForegroundColor Yellow
if (Test-Path $luacheckExe) {
    $targetDirs = @("lua", "tests") | Where-Object { Test-Path (Join-Path $projectRoot $_) }
    if ($targetDirs.Count -gt 0) {
        $targets = $targetDirs | ForEach-Object { Join-Path $projectRoot $_ }
        & $luacheckExe @targets --config (Join-Path $projectRoot ".luacheckrc")
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[-] Luacheck Linting FAILED!" -ForegroundColor Red
            $failed = $true
        } else {
            Write-Host "[+] Luacheck Linting PASSED (0 warnings)." -ForegroundColor Green
        }
    } else {
        Write-Host "[*] No Lua source directories found yet to lint." -ForegroundColor Gray
    }
} else {
    Write-Host "[!] Warning: Luacheck not found at $luacheckExe. Skipping linting." -ForegroundColor Yellow
}

# 3. Headless LuaUnit Tests
Write-Host "`n[3/3] Running LuaUnit Test Suites..." -ForegroundColor Yellow
if (Test-Path $luaExe) {
    $testFiles = Get-ChildItem -Path $testsDir -Filter "test_*.lua" -ErrorAction SilentlyContinue
    if ($testFiles.Count -gt 0) {
        foreach ($testFile in $testFiles) {
            Write-Host "  -> Running: $($testFile.Name)" -ForegroundColor Cyan
            & $luaExe $testFile.FullName
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[-] Test Suite $($testFile.Name) FAILED!" -ForegroundColor Red
                $failed = $true
            }
        }
        if (-not $failed) {
            Write-Host "[+] All LuaUnit test suites PASSED." -ForegroundColor Green
        }
    } else {
        Write-Host "[*] No test_*.lua test suites found yet." -ForegroundColor Gray
    }
} else {
    Write-Host "[-] Error: Lua runtime not found at $luaExe!" -ForegroundColor Red
    $failed = $true
}

$startTime.Stop()
$elapsedSec = [math]::Round($startTime.Elapsed.TotalSeconds, 2)

Write-Host "`n============================================================" -ForegroundColor Cyan
if ($failed) {
    Write-Host "PIPELINE RESULT: FAILED ($elapsedSec s)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "PIPELINE RESULT: PASSED ($elapsedSec s)" -ForegroundColor Green
    exit 0
}
