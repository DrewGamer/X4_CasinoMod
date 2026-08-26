---
name: environment-manager
description: Use this skill to acquire and install missing frameworks, libraries, or CLI tools required for development. It enforces supervised execution and resilient fallback logic.
---

# SKILL: Environment Manager

This skill implements the A9 SUPERVISED EXECUTION pattern for mutating the local environment. It must ONLY be invoked when a required dependency is missing.

## DEPENDENCIES
- Requires the `human-checkpoint` skill to authorize installations.

## PROCEDURE

1. **Identify the Dependency:**
   - Determine exactly what package manager (e.g., npm, pip, gradle, brew) and package name is needed.

2. **Authorization Gate:**
   - You MUST invoke the `human-checkpoint` skill to ask the user: "Do you approve the installation of `<package>` using `<manager>`?"
   - If the user denies, EXIT the skill and report failure to the orchestrator.

3. **Execution Loop (S7 Deterministic Tool Bridge):**
   - **Attempt 1 (Global):**
     - Use the `run_command` tool to attempt a global installation (e.g., `npm install -g <package>`).
     - Check the return code. If successful, EXIT and report success.
   - **Attempt 2 (Local/Project):**
     - If global fails, use `run_command` to attempt a project-local installation (e.g., `npm install <package>`).
     - Check the return code. If successful, EXIT and report success.
   
4. **Human Escalation:**
   - If BOTH automated installation attempts fail, you must invoke the `human-checkpoint` skill again.
   - Prompt the user: "Both global and local automated installations for `<package>` failed. Please try to resolve this manually. Reply with 'Fixed' if you acquired it, or 'Cannot Acquire' if we should rethink the tech stack."
   - If the user says they fixed it, EXIT and report success.
   - If the user says "Cannot Acquire", EXIT and report FATAL_FAILURE so the orchestrator can trigger a re-architecture phase.

## ANTI-PATTERNS
- **Token-Laundering**: NEVER attempt to install a tool without passing the initial `human-checkpoint` gate.
- **Silent Failures**: Never pretend a tool installed successfully if the `run_command` exited with a non-zero status.
- **Toolless Assertion**: Always verify the installation actually worked by running a deterministic check (e.g., `<package> --version`).
