<#
.SYNOPSIS
    Syncs the latest agentic XP skills and personas from DrewGamer/agent-xp-workflow.
.DESCRIPTION
    Pulls the latest skills, personas, and utilities from the upstream repository into
    the current project's .agents directory without overwriting local plans or custom hooks.
#>

[CmdletBinding()]
param (
    [string]$RepoUrl = "https://github.com/DrewGamer/agent-xp-workflow.git",
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

# 1. Locate project root containing .agents
$currentDir = Get-Location
$projectRoot = $currentDir.Path
while (-not (Test-Path (Join-Path $projectRoot ".agents")) -and (Split-Path $projectRoot -Parent)) {
    $projectRoot = Split-Path $projectRoot -Parent
}

if (-not (Test-Path (Join-Path $projectRoot ".agents"))) {
    Write-Error "Could not locate a .agents directory in $currentDir or any parent directory."
    exit 1
}

$agentsDir = Join-Path $projectRoot ".agents"
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-xp-sync-" + [System.Guid]::NewGuid().ToString("N"))

Write-Host "Syncing agent workflow from $RepoUrl ($Branch)..." -ForegroundColor Cyan

try {
    # 2. Shallow clone upstream into temp directory
    git clone --depth 1 --branch $Branch $RepoUrl $tempDir --quiet
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone upstream repository."
    }

    # 3. Sync skills
    $srcSkills = Join-Path $tempDir "skills"
    $destSkills = Join-Path $agentsDir "skills"
    if (Test-Path $srcSkills) {
        if (-not (Test-Path $destSkills)) { New-Item -ItemType Directory -Path $destSkills -Force | Out-Null }
        Copy-Item -Path "$srcSkills\*" -Destination $destSkills -Recurse -Force
        Write-Host "  [+] Synced skills -> $destSkills" -ForegroundColor Green
    }

    # 4. Sync personas
    $srcPersonas = Join-Path $tempDir "personas"
    $destPersonas = Join-Path $agentsDir "personas"
    if (Test-Path $srcPersonas) {
        if (-not (Test-Path $destPersonas)) { New-Item -ItemType Directory -Path $destPersonas -Force | Out-Null }
        Copy-Item -Path "$srcPersonas\*" -Destination $destPersonas -Recurse -Force
        Write-Host "  [+] Synced personas -> $destPersonas" -ForegroundColor Green
    }

    # 5. Sync scripts (sync_workflow.ps1, security_gate.template.ps1)
    $srcScripts = Join-Path $tempDir "scripts"
    $destScripts = Join-Path $agentsDir "scripts"
    if (Test-Path $srcScripts) {
        if (-not (Test-Path $destScripts)) { New-Item -ItemType Directory -Path $destScripts -Force | Out-Null }
        Get-ChildItem -Path $srcScripts | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $destScripts -Force
            Write-Host "  [+] Synced script -> $destScripts\$($_.Name)" -ForegroundColor Green
        }
    }

    # 6. Initialize hooks.json if it doesn't already exist
    $srcHooks = Join-Path $tempDir "hooks.json"
    $destHooks = Join-Path $agentsDir "hooks.json"
    if ((Test-Path $srcHooks) -and (-not (Test-Path $destHooks))) {
        Copy-Item -Path $srcHooks -Destination $destHooks -Force
        Write-Host "  [+] Initialized hooks.json -> $destHooks" -ForegroundColor Green
    }

    # 7. Advise if security_gate.ps1 is missing
    $secGate = Join-Path $destScripts "security_gate.ps1"
    $secGateTemplate = Join-Path $destScripts "security_gate.template.ps1"
    if ((-not (Test-Path $secGate)) -and (Test-Path $secGateTemplate)) {
        Copy-Item -Path $secGateTemplate -Destination $secGate -Force
        Write-Host "  [!] Initialized security_gate.ps1 from template. (Remember to customize allowed commands if needed)." -ForegroundColor Yellow
    }

    Write-Host "`nWorkflow successfully synced from upstream!" -ForegroundColor Cyan
}
catch {
    Write-Error "Sync failed: $_"
    exit 1
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
