# PowerShell Build & Packaging Script for X4 Casino Mod
# Builds production distribution in dist/x4_casino_mod/ and dist/x4_casino_mod.zip

[CmdletBinding()]
param (
    [ValidateSet("release", "debug")]
    [string]$BuildType = "release",
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$distDir = Join-Path $projectRoot "dist"
$modDistDir = Join-Path $distDir "x4_casino_mod"
$zipPath = Join-Path $distDir "x4_casino_mod.zip"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "X4 Casino Mod - Build & Packaging ($BuildType)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Run Verification Pipeline unless skipped
if (-not $SkipTests) {
    Write-Host "`n[1/4] Running Verification & Test Suite..." -ForegroundColor Yellow
    $testScript = Join-Path $scriptDir "test.ps1"
    & powershell -ExecutionPolicy Bypass -File $testScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[-] Build aborted: Tests or validation failed!" -ForegroundColor Red
        exit 1
    }
}

# 2. Clean & Prepare dist directory
Write-Host "`n[2/4] Cleaning and preparing dist directory..." -ForegroundColor Yellow
if (Test-Path $modDistDir) {
    Remove-Item -Path $modDistDir -Recurse -Force
}
if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}
New-Item -ItemType Directory -Path $modDistDir -Force | Out-Null

# 3. Copy Production Assets
Write-Host "`n[3/4] Assembling production mod assets into $modDistDir..." -ForegroundColor Yellow

# Copy root metadata
Copy-Item (Join-Path $projectRoot "content.xml") -Destination $modDistDir -Force
if (Test-Path (Join-Path $projectRoot "README.md")) {
    Copy-Item (Join-Path $projectRoot "README.md") -Destination $modDistDir -Force
}

# Directories to bundle
$bundleDirs = @("lua", "ui", "md", "t")
foreach ($dir in $bundleDirs) {
    $srcPath = Join-Path $projectRoot $dir
    if (Test-Path $srcPath) {
        $destPath = Join-Path $modDistDir $dir
        Copy-Item -Path $srcPath -Destination $modDistDir -Recurse -Force
        Write-Host "  [+] Bundled: $dir/" -ForegroundColor Green
    }
}

# 4. Compress to Release Zip
Write-Host "`n[4/4] Creating distribution archive: $zipPath..." -ForegroundColor Yellow
Compress-Archive -Path "$modDistDir\*" -DestinationPath $zipPath -Force

$zipSize = (Get-Item $zipPath).Length
$zipSizeKb = [math]::Round($zipSize / 1024, 2)

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
Write-Host "Output Directory: $modDistDir" -ForegroundColor Gray
Write-Host "Distribution Zip: $zipPath ($zipSizeKb KB)" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan
exit 0
