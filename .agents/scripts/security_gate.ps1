# PowerShell Hook for Antigravity: Security and Workspace Boundary Gate
# Restricts AI execution strictly to the workspace boundary:
# - Blocks any commands or file operations outside C:\Projects\X4_CasinoMod
# - Preserves human-in-the-loop gate for PR merging and branch destruction
# - Protects the security gate itself from tampering
# - Auto-approves all safe development tools, compilers, test runners, bash, and git operations within the workspace

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    # Read from Console standard input, fallback to pipeline $input if available
    $rawInput = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($rawInput) -and $input) {
        $rawInput = ($input | Out-String)
    }

    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        [PSCustomObject]@{ decision = "ask"; reason = "No input payload received" } | ConvertTo-Json -Compress
        exit 0
    }

    $payload = $rawInput | ConvertFrom-Json
    $toolCall = $payload.toolCall
    $toolName = if ($toolCall.name) { $toolCall.name } else { "" }
    $args = $toolCall.args

    # Determine Workspace Root (dynamic from payload or current directory)
    $workspaceRoot = if ($payload.workspacePaths -and $payload.workspacePaths.Count -gt 0) {
        $payload.workspacePaths[0]
    } else {
        (Get-Location).Path
    }
    $normalizedWorkspace = [System.IO.Path]::GetFullPath($workspaceRoot).TrimEnd('\', '/')

    # -------------------------------------------------------------
    # 1. FILE EDITING TOOLS (write_to_file, replace_file_content)
    # -------------------------------------------------------------
    if ($toolName -in @("write_to_file", "replace_file_content")) {
        $targetFile = $args.TargetFile
        if (-not $targetFile) {
            [PSCustomObject]@{ decision = "ask"; reason = "Missing TargetFile argument" } | ConvertTo-Json -Compress
            exit 0
        }

        $fullPath = [System.IO.Path]::GetFullPath($targetFile)

        # Enforce workspace boundary: strictly block edits outside workspace
        if (-not $fullPath.StartsWith($normalizedWorkspace, [System.StringComparison]::OrdinalIgnoreCase)) {
            [PSCustomObject]@{
                decision = "ask"
                reason = "File edit is outside workspace boundary: $targetFile"
            } | ConvertTo-Json -Compress
            exit 0
        }

        $relPath = $fullPath.Substring($normalizedWorkspace.Length).TrimStart('\', '/')

        # Protect the security gate itself and hooks config from self-tampering
        if ($relPath -match '^(\.agents[\\/]scripts[\\/]security_gate\.ps1|\.agents[\\/]hooks\.json)$') {
            [PSCustomObject]@{
                decision = "ask"
                reason = "Modifying the security gate configuration requires human approval."
            } | ConvertTo-Json -Compress
            exit 0
        }

        # Normal project files, code, tests, plans, personas, and skills within workspace are allowed
        [PSCustomObject]@{ decision = "allow" } | ConvertTo-Json -Compress
        exit 0
    }

    # -------------------------------------------------------------
    # 2. TERMINAL COMMAND EXECUTION (run_command)
    # -------------------------------------------------------------
    if ($toolName -eq "run_command") {
        $cmd = if ($args.CommandLine) { $args.CommandLine.Trim() } else { "" }
        $cwd = if ($args.Cwd) { $args.Cwd.Trim() } else { $normalizedWorkspace }

        # Check working directory boundary: MUST be within workspace
        $fullCwd = [System.IO.Path]::GetFullPath($cwd)
        if (-not $fullCwd.StartsWith($normalizedWorkspace, [System.StringComparison]::OrdinalIgnoreCase)) {
            [PSCustomObject]@{
                decision = "ask"
                reason = "Command working directory ($cwd) is outside project workspace."
            } | ConvertTo-Json -Compress
            exit 0
        }

        # RESTRICTION 1: PR Merge / Review Gate (Must be reviewed/approved by Human)
        if ($cmd -match '\bgh\s+pr\s+merge\b' -or 
            $cmd -match '\bgh\s+pr\s+review\b.*(--approve|-a\b)' -or
            $cmd -match '\bgit\s+merge\s+(main|master)\b') {
            [PSCustomObject]@{
                decision = "ask"
                reason = "Pull request approval and merging to main branch require explicit human review."
            } | ConvertTo-Json -Compress
            exit 0
        }

        # RESTRICTION 2: Tampering with security gate via shell commands
        if ($cmd -match '(\.agents[\\/]scripts[\\/]security_gate\.ps1|\.agents[\\/]hooks\.json)\b' -and 
            $cmd -match '(rm|del|rmdir|remove-item|set-content|out-file|>|>>|mv|move-item)') {
            [PSCustomObject]@{
                decision = "ask"
                reason = "Modifying or deleting the security gate via shell requires human approval."
            } | ConvertTo-Json -Compress
            exit 0
        }

        # RESTRICTION 3: Catastrophic git destruction
        if ($cmd -match '\b(rm|Remove-Item)\s+.*-r.*\b\.git\b' -or
            $cmd -match '\bgit\s+clean\s+.*-fdx\b') {
            [PSCustomObject]@{
                decision = "ask"
                reason = "Destructive repo commands require explicit human confirmation."
            } | ConvertTo-Json -Compress
            exit 0
        }

        # BOUNDARY CHECK: Scan command for explicit absolute paths outside the workspace
        # Matches drive paths like C:\..., D:/..., etc.
        $absPathMatches = [regex]::Matches($cmd, '([a-zA-Z]:[\\/][^\s"''`]+)')
        $outsideWorkspace = $false
        foreach ($m in $absPathMatches) {
            $rawPath = $m.Value.TrimEnd(';', ',', '"', "'")
            # Exclude known benign system runtime / program directories (Python, Git, PowerShell binaries)
            if ($rawPath -match '^(C:[\\/](Windows|Program Files|Program Files \(x86\)))' -or
                $rawPath -match '[\\/]AppData[\\/]Local[\\/]Programs[\\/]') {
                continue
            }
            try {
                $targetPath = [System.IO.Path]::GetFullPath($rawPath)
                if (-not $targetPath.StartsWith($normalizedWorkspace, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $outsideWorkspace = $true
                    break
                }
            } catch {
                # In case regex matched invalid path characters, continue
            }
        }

        if ($outsideWorkspace) {
            [PSCustomObject]@{
                decision = "ask"
                reason = "Command references filesystem path outside workspace boundary: $($m.Value)"
            } | ConvertTo-Json -Compress
            exit 0
        }

        # In-workspace command execution: ALLOWED
        # Allows python, lua, bash, sh, pwsh, git, gh, pytest, luacheck, compilers, curl, grep, etc.
        [PSCustomObject]@{ decision = "allow" } | ConvertTo-Json -Compress
        exit 0
    }

    # For any other tool types (default safe fallback)
    [PSCustomObject]@{ decision = "allow" } | ConvertTo-Json -Compress
}
catch {
    # If script errors, fallback to ask so system safety is not compromised
    [PSCustomObject]@{
        decision = "ask"
        reason = "Security hook encountered an error: $($_.Exception.Message)"
    } | ConvertTo-Json -Compress
}
