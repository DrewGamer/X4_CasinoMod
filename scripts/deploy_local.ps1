# PowerShell Local Deployment Script for X4 Casino Mod
# Deploys built mod from dist/x4_casino_mod/ to the local X4 extensions directory.

[CmdletBinding()]
param (
    [switch]$ForceCopy
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$configFile = Join-Path $projectRoot "config.local.json"
$configTemplate = Join-Path $projectRoot "config.local.json.template"
$modDistDir = Join-Path $projectRoot "dist\x4_casino_mod"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "X4 Casino Mod - Local Game Deployment" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Build latest assets
Write-Host "[*] Building latest distribution assets..." -ForegroundColor Yellow
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir "build.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Host "[-] Build failed. Deployment aborted." -ForegroundColor Red
    exit 1
}

# 2. Load Local Config
if (-not (Test-Path $configFile)) {
    Write-Host "[!] Warning: config.local.json not found." -ForegroundColor Yellow
    Write-Host "    Copying template from config.local.json.template..." -ForegroundColor Yellow
    Copy-Item $configTemplate $configFile
    Write-Host "[!] Please configure paths in config.local.json to deploy to your X4 game directory." -ForegroundColor Yellow
    exit 1
}

$config = Get-Content $configFile -Raw | ConvertFrom-Json
$deployMode = if ($config.deploy_mode) { $config.deploy_mode } else { "copy" }
$targetPath = ""

if ($config.x4_install_path -and (Test-Path $config.x4_install_path)) {
    $targetPath = Join-Path $config.x4_install_path "extensions\x4_casino_mod"
} elseif ($config.x4_user_extensions_path -and (Test-Path (Split-Path $config.x4_user_extensions_path -Parent))) {
    $targetPath = Join-Path $config.x4_user_extensions_path "x4_casino_mod"
} else {
    Write-Host "[!] Error: No valid X4 installation path found in config.local.json." -ForegroundColor Red
    Write-Host "    Edit config.local.json with your actual X4 game directory (e.g. Steam/steamapps/common/X4 Foundations)." -ForegroundColor Yellow
    exit 1
}

Write-Host "[+] Target Deployment Path: $targetPath" -ForegroundColor Cyan
Write-Host "[+] Deployment Mode: $deployMode" -ForegroundColor Cyan

# Ensure parent extensions directory exists
$extensionsDir = Split-Path $targetPath -Parent
if (-not (Test-Path $extensionsDir)) {
    New-Item -ItemType Directory -Path $extensionsDir -Force | Out-Null
}

# Remove existing link/directory
if (Test-Path $targetPath) {
    Write-Host "  [-] Removing existing installation at $targetPath..." -ForegroundColor Yellow
    $item = Get-Item $targetPath
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        [System.IO.Directory]::Delete($targetPath)
    } else {
        Remove-Item -Path $targetPath -Recurse -Force
    }
}

# Deploy via Symlink or Copy
if ($deployMode -eq "symlink" -and -not $ForceCopy) {
    try {
        New-Item -ItemType SymbolicLink -Path $targetPath -Target (Join-Path $projectRoot "dist\x4_casino_mod") -Force | Out-Null
        Write-Host "[+] Successfully created symbolic link to $targetPath" -ForegroundColor Green
    } catch {
        Write-Host "[!] Symlink creation failed (requires Admin/Developer Mode). Falling back to direct copy..." -ForegroundColor Yellow
        Copy-Item -Path (Join-Path $projectRoot "dist\x4_casino_mod") -Destination $targetPath -Recurse -Force
        Write-Host "[+] Successfully copied mod to $targetPath" -ForegroundColor Green
    }
} else {
    Copy-Item -Path (Join-Path $projectRoot "dist\x4_casino_mod") -Destination $targetPath -Recurse -Force
    Write-Host "[+] Successfully copied mod to $targetPath" -ForegroundColor Green
}

Write-Host "`nDEPLOYMENT COMPLETE! Ready for in-game testing." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
