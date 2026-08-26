# PowerShell Hook for Antigravity: Security and Streamline Gate
# Enforces workspace boundaries, human PR review/merge gate, and .agents protection while auto-approving safe dev workflows.

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    $rawInput = [Console]::In.ReadToEnd()
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
        
        # Check workspace boundary
        if (-not $fullPath.StartsWith($normalizedWorkspace, [System.StringComparison]::OrdinalIgnoreCase)) {
            [PSCustomObject]@{
                decision = "ask"
                reason = "File edit is outside workspace boundary: $targetFile"
            } | ConvertTo-Json -Compress
            exit 0
        }

        # Check .agents protection (plans, readme, changelog are allowed)
        $relPath = $fullPath.Substring($normalizedWorkspace.Length).TrimStart('\', '/')
        if ($relPath -match '^\.agents[\\/]') {
            # Allowed exception: .agents/plans/*
            if ($relPath -match '^\.agents[\\/]plans[\\/]') {
                [PSCustomObject]@{ decision = "allow" } | ConvertTo-Json -Compress
                exit 0
            }

            # Any other file in .agents/ (personas, skills, rules, hooks, etc.) requires approval
            [PSCustomObject]@{
                decision = "ask"
                reason = "Modifications to agent configuration files ($relPath) require human approval."
            } | ConvertTo-Json -Compress
            exit 0
        }

        # Normal project files within workspace
        [PSCustomObject]@{ decision = "allow" } | ConvertTo-Json -Compress
        exit 0
    }

    # -------------------------------------------------------------
    # 2. TERMINAL COMMAND EXECUTION (run_command)
    # -------------------------------------------------------------
    if ($toolName -eq "run_command") {
        $cmd = if ($args.CommandLine) { $args.CommandLine.Trim() } else { "" }
        $cwd = if ($args.Cwd) { $args.Cwd.Trim() } else { $normalizedWorkspace }

        # Check working directory boundary
        $fullCwd = [System.IO.Path]::GetFullPath($cwd)
        if (-not $fullCwd.StartsWith($normalizedWorkspace, [System.StringComparison]::OrdinalIgnoreCase)) {
            [PSCustomObject]@{
                decision = "ask"
                reason = "Command working directory ($cwd) is outside project workspace."
            } | ConvertTo-Json -Compress
            exit 0
        }

        # RESTRICTION 1: PR Approval & Merge Gate (MUST be done by Human)
        if ($cmd -match '\bgh\s+pr\s+merge\b' -or 
            $cmd -match '\bgh\s+pr\s+review\b.*(--approve|-a\b)' -or
            $cmd -match '\bgit\s+merge\b') {
            [PSCustomObject]@{
                decision = "ask"
                reason = "Pull request approval and branch merging require explicit human review."
            } | ConvertTo-Json -Compress
            exit 0
        }

        # RESTRICTION 2: Direct modifications/deletions of protected .agents/ configs via shell
        if ($cmd -match '\.agents[\\/](personas|skills|rules|hooks|scripts)\b' -and 
            $cmd -match '(rm|del|rmdir|remove-item|set-content|out-file|>|>>|mv|move-item)') {
            [PSCustomObject]@{
                decision = "ask"
                reason = "Shell commands targeting protected agent configurations require human approval."
            } | ConvertTo-Json -Compress
            exit 0
        }

        # -------------------------------------------------------------------------
        # ALLOWED DEV COMMANDS (Streamlined Auto-Approval)
        # Customize this section for your project's specific toolchain!
        # -------------------------------------------------------------------------

        # 1. Project Toolchains (e.g., Flutter, Python, Node, Cargo, 7z, etc.)
        # Example for Flutter/Dart:   '^\s*(flutter|dart)\b'
        # Example for Python:         '^\s*(python|pytest|pip|poetry|uv)\b'
        # Example for Node/JS:        '^\s*(npm|pnpm|yarn|node|npx)\b'
        # Example for Game Mods/Zip:  '^\s*(7z|7za|tar|zip|python)\b'
        if ($cmd -match '^\s*(python|pytest|7z|7za|tar|zip)\b') {
            [PSCustomObject]@{ decision = "allow" } | ConvertTo-Json -Compress
            exit 0
        }

        # 2. Build & packaging scripts
        if ($cmd -match '^\s*(\./gradlew|gradlew|gradlew\.bat|cargo|make)\b') {
            [PSCustomObject]@{ decision = "allow" } | ConvertTo-Json -Compress
            exit 0
        }

        # 3. Git safe commands (status, branch, checkout, switch, diff, log, show, rev-parse, add, commit, push, tag, fetch, pull)
        if ($cmd -match '^\s*git\s+(status|branch|checkout|switch|diff|log|show|rev-parse|add|commit|push|tag|fetch|pull)\b') {
            [PSCustomObject]@{ decision = "allow" } | ConvertTo-Json -Compress
            exit 0
        }

        # 4. GitHub CLI safe commands (pr create, pr view, pr list, pr status, pr diff, release view, release create, release upload, release list)
        if ($cmd -match '^\s*gh\s+(pr\s+(create|view|list|status|diff)|release\s+(view|create|upload|list))\b') {
            [PSCustomObject]@{ decision = "allow" } | ConvertTo-Json -Compress
            exit 0
        }

        # 5. Safe read/inspection commands (dir, ls, cat, type, echo, pwd, test, Get-ChildItem, Get-Content)
        if ($cmd -match '^\s*(ls|dir|cat|type|echo|pwd|Get-ChildItem|Get-Content)\b') {
            [PSCustomObject]@{ decision = "allow" } | ConvertTo-Json -Compress
            exit 0
        }

        # Default fallback for any other unrecognized or complex commands: ask user
        [PSCustomObject]@{
            decision = "ask"
            reason = "Command requires user confirmation."
        } | ConvertTo-Json -Compress
        exit 0
    }

    # For any other tool types (default safe fallback)
    [PSCustomObject]@{ decision = "allow" } | ConvertTo-Json -Compress
}
catch {
    # If script errors, gracefully fallback to ask so work is not blocked
    [PSCustomObject]@{
        decision = "ask"
        reason = "Security hook encountered an error: $($_.Exception.Message)"
    } | ConvertTo-Json -Compress
}
