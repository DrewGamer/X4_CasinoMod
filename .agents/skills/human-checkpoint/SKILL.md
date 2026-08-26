---
name: human-checkpoint
description: Use this skill to halt execution and request explicit human approval or intervention before proceeding with irreversible actions, architecture decisions, or when automated fallbacks fail.
---

# SKILL: Human Checkpoint (B10)

This skill implements the B10 HUMAN CHECKPOINT architectural pattern. It acts as an explicit gate to prevent the agent from proceeding without authorization on consequential steps.

## WHEN TO USE
- A design/architectural proposal is ready for review.
- A Pull Request (or code feature) is ready for review.
- A new tool/framework needs to be installed.
- An automated fallback mechanism has failed (e.g., tool installation failure) and manual intervention is required.

## PROCEDURE

1. **Prepare the Context:**
   - Gather the exact artifact that needs review (e.g., the architecture markdown, the code diff, the name of the missing tool).
   - If this is a failure escalation, gather the exact error message and what was attempted.

2. **Halt and Prompt:**
   - Present the context clearly to the human user in the chat.
   - Explicitly ask the user for their decision.
   - Provide clear options (e.g., "Approve", "Request Changes", "I have installed it manually", "Cannot acquire tool").

3. **Wait:**
   - Do NOT proceed with the parent workflow until the user responds.
   - (In Antigravity, simply end your turn and let the user type a response).

4. **Return Verdict:**
   - Once the user responds, parse their intent.
   - Return the structured verdict (e.g., `APPROVED`, `REFINE: <reason>`, `RESOLVED_MANUALLY`, `FATAL_FAILURE`) back to the calling orchestrator or skill.

## ANTI-PATTERNS
- **False-Choice Gate**: Do not ask the user for approval if you are just going to proceed anyway.
- **Chatty Gate**: Do not use this skill for trivial decisions (like naming a variable). Reserve it for the milestones defined in the orchestrator pipeline.
