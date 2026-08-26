---
name: xp-orchestrator
description: Use this orchestrator to manage the development lifecycle of a software project, mod, or application using extreme programming. It triggers when a new project is initiated or when new features are added to an existing backlog. It routes tasks to an agentic development team, persists plans in `.agents/plans/`, manages iterative development on a feature branch (with human verification to prevent branch nesting or misalignment), pauses for human architectural approvals, resilient tool acquisition, post-packaging manual testing, and final release packaging from main after PR merge, uploading the artifact to a release tag.
---

# SKILL: Project XP Lifecycle Orchestrator

This is the primary orchestrator module that realizes the STAFFED PLAN and PIPELINE architectural shapes for the XP workflow. 

## DEPENDENCIES
- Assets: `assets/xp-state.template.md`
- Personas: `xp-architect`, `xp-developer`
- Skills: `human-checkpoint`, `environment-manager`, `release-packager`
- External CLI: `git`, `gh`

## PROCEDURE

**Phase 0: Initialization**
1. Check for the existence of an `.agents/plans/xp-state.md` plan artifact in the workspace.
2. If it does not exist, initialize it using `assets/xp-state.template.md` as the base, ensuring the `.agents/plans` directory is created.
3. RELOAD the `.agents/plans/xp-state.md` artifact into your context. (B4 PLAN MEMENTO)
4. Check the current branch with `git branch --show-current`. If you are already on a feature branch, invoke the `human-checkpoint` skill to confirm if this branch aligns with the current task.
   - If confirmed, stay on it.
   - If not confirmed, or if you are not currently on a feature branch, list all existing branches using `git branch`. Invoke the `human-checkpoint` skill to ask the human if they want to choose one of the existing branches or if a new feature branch should be created.
   - Execute `git checkout <chosen-branch>` or `git checkout -b <new-branch-name>` based on the human's decision.

**Phase 1: Architecture & Design**
1. Read the user's initial request or feature backlog.
2. Invoke the `xp-architect` persona in a new child thread (CHILD-THREAD SPAWN), passing it the user's request.
3. When the `xp-architect` returns an architectural blueprint, invoke the `human-checkpoint` skill to request human approval.
   - If the human requests changes, re-invoke the `xp-architect` with the feedback.
   - If approved, update `.agents/plans/xp-state.md` with the approved tech stack and move to Phase 2.

**Phase 2: XP Development Loop**
1. Invoke the `xp-developer` persona in a new child thread to begin implementation of the first pending task in the `.agents/plans/xp-state.md` backlog.
2. **Tooling Interruption (Resilience Loop):**
   - If the `xp-developer` reports that a required tool or framework is missing, immediately suspend development.
   - Invoke the `environment-manager` skill to handle acquisition.
   - The `environment-manager` will handle human approvals and fallback logic.
   - If the `environment-manager` reports a `FATAL_FAILURE` (tools could not be acquired manually or automatically), you MUST abort development, invoke the `xp-architect` to revise the stack, and return to Phase 1's human approval gate.
   - If the tool is acquired successfully, re-invoke the `xp-developer` to resume.
3. Once the `xp-developer` finishes the feature and prepares the diff/PR, update the `.agents/plans/xp-state.md` status to indicate the task is complete.

**Phase 3: Intermediate Release Packaging**
1. RELOAD `.agents/plans/xp-state.md` into your context. (B4 PLAN MEMENTO)
2. Read the `Continuous Release Tag` and `Continuous Release Name` from Section 7 of `xp-state.md`. Read the `Build Type Override` field — if it is blank or absent, the build type is `release`; if it is set to `debug`, the build type is `debug`.
3. Invoke the `release-packager` skill with the determined build type (default: `release`). The packager builds on the CURRENT FEATURE BRANCH. It MUST NOT merge to main, create pull requests, or create new build tags.
4. **Verify Continuous Release on GitHub (S7 + S4):**
   - Run `gh release view <continuous_release_tag> --json tagName,name` to verify the tag and release exist on GitHub.
   - If the command succeeds (exit code 0), the release exists — proceed to step 5.
   - If the command fails (tag/release not found), invoke the `human-checkpoint` skill. Present the human with the following options:
     - **Create it:** Create the missing release with `gh release create <continuous_release_tag> --title "<continuous_release_name>" --prerelease --notes "Continuous build"`, then proceed to step 5.
     - **Use a different name:** The human provides an alternative tag/release name. Update Section 7 of `xp-state.md` with the new values, then re-run step 4 to verify the new name.
     - **Abort:** Halt Phase 3 entirely.
5. **Upload Artifact to Continuous Release (MANDATORY — never skip this step):**
   - Run `git tag -f <continuous_release_tag>` to force update the local tag to the current commit.
   - Run `git push -f origin <continuous_release_tag>` to push the updated tag to GitHub.
   - Run `gh release upload <continuous_release_tag> <artifact-path> --clobber` to upload the newly built package/artifact to the continuous release.
   - These three commands MUST all be executed. Do NOT skip the upload even if prior steps took many turns or encountered minor issues.
6. Update `.agents/plans/xp-state.md` to record the continuous build upload checkpoint. Present the final output path and the continuous release link to the user. Proceed to Phase 4.

**Phase 4: Manual Testing Loop**
1. Invoke the `human-checkpoint` skill to request a human to manually test the packaged artifact/application to identify any issues or bugs.
2. If the human finds bugs or issues, route back to Phase 2: invoke the `xp-developer` to address the specific feedback.
3. If the human approves the release, proceed to Phase 5.

**Phase 5: GitHub PR & Release**
1. **Update Changelog (S7):**
   - RELOAD `.agents/plans/xp-state.md` into your context. (B4 PLAN MEMENTO)
   - Run `git log main..HEAD --oneline` to get the commit history for the feature branch.
   - Read Section 2 (Active Goal) and Section 4 (Work Backlog) from `.agents/plans/xp-state.md` to identify the feature name and all completed tasks.
   - Check if `CHANGELOG.md` exists at the project root. If it does NOT exist, create it with this header:
     ```
     # Changelog

     All notable changes to this project will be documented in this file.

     The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
     and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
     ```
   - Read the existing `CHANGELOG.md` content. Compile a new changelog entry under a `## [Unreleased]` section. Categorize each completed backlog item using standard Keep a Changelog subheadings (`### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, `### Security`):
     - `### Added`: New user-facing capabilities or features.
     - `### Changed`: Modifications to existing behavior or architecture.
     - `### Fixed`: Bug fixes or issues found during manual testing.
     - `### Security`: Security rules, permissions, or authentication updates.
   - If an `## [Unreleased]` section already exists (from a prior cycle where the release was skipped), APPEND the new entries under the appropriate category subheadings — do not overwrite prior entries. If no `## [Unreleased]` section exists, create one after the header.
   - Write the updated `CHANGELOG.md`, then stage and commit: `git add CHANGELOG.md` followed by `git commit -m "docs: update changelog for <feature-name>"`.
2. Use the GitHub CLI (`gh pr create`) to create a pull request for the feature branch.
3. Invoke the `human-checkpoint` skill to ask the human to confirm that the branch merge to main has been completed.
4. Once the branch merge is confirmed, check out the `main` branch, pull the latest changes (`git checkout main && git pull`), and delete the local feature branch (`git branch -d <feature-branch>`).
5. **Release Gate (B10 + B16):**
   - Read the `## [Unreleased]` section from `CHANGELOG.md` to summarize what changed, highlighting user-facing additions and fixes.
   - Invoke the `human-checkpoint` skill. Present the changelog summary and ask: "Would you like to create a release for these changes?" Offer these options:
     - **Create release**: Proceed with packaging, tagging, and release creation (steps 6-10).
     - **Skip release**: End Phase 5 now. Changes are merged to main but no release artifact is created.
   - If the human selects **Skip release**: update `.agents/plans/xp-state.md` Section 6 to record `- [x] Release Skipped (human decision)`, then **HALT Phase 5** (B16 EARLY EXIT). Do NOT invoke release-packager, do NOT create a tag, do NOT create a release.
6. Invoke the `release-packager` skill to bundle the completed code into a final release artifact from the main branch.
7. **Determine Next Semver Tag (S7 + S4):**
   - Run `git tag -l "v*" --sort=-v:refname` to list all existing version tags, sorted newest first.
   - Parse the output to find the latest tag matching the semver pattern: `v<MAJOR>.<MINOR>.<PATCH>[-<prerelease>]`.
   - Suggest the next version tag using these rules:
     - If no valid semver tags exist, suggest `v0.1.0-beta`.
     - If the latest tag has a pre-release label (e.g. `v0.9.0-beta`), suggest incrementing MINOR (e.g. `v0.10.0-beta`).
     - If the latest tag is stable (no pre-release label), suggest incrementing MINOR (e.g. `v1.0.0` -> `v1.1.0`).
   - Validate the proposed tag against the semver regex: `^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*)?$`. If validation fails, regenerate (max 3 attempts).
8. **Tag Approval Gate (B10):**
   - Invoke the `human-checkpoint` skill. Present the proposed tag, the latest existing tag, and the rationale (minor bump / patch bump / graduation from pre-release). Offer these options:
     - **Approve**: Use the proposed tag as-is.
     - **Override**: The human provides their own tag (e.g. to do a major bump, patch bump, or drop the pre-release label to graduate to stable).
   - If the human provides a custom tag, validate it against the semver regex. If it fails, inform the human the tag does not follow semver conventions and ask them to revise.
9. **Create Release with User-Facing Release Notes (S7):**
   - Read the `## [Unreleased]` section from `CHANGELOG.md` and extract only user-facing entries for the release notes:
     - Include items from `### Added`, `### Fixed`, and any user-visible capabilities or improvements from `### Changed` or `### Security`.
     - Exclude internal developer-only items (such as test suite reorganization, internal refactoring, or tool configuration).
     - If all unreleased changes were internal/developer-only, summarize them simply as: `### Changed` with `- Under-the-hood performance, stability, and security improvements.`
   - Run `gh release create <approved-tag> <artifact-path> --title "<approved-tag>" --notes "<user-facing-release-notes>"` to create the release with the approved semver tag and user-facing notes.
   - Verify the release was created successfully by checking the exit code.
   - After successful creation, update `CHANGELOG.md`: replace `## [Unreleased]` with `## [<approved-tag>] - <YYYY-MM-DD>` (using today's date, preserving all entries including internal ones), and add a fresh empty `## [Unreleased]` section above it. Also add/update the comparison link reference at the bottom of `CHANGELOG.md`. Commit and push: `git add CHANGELOG.md && git commit -m "docs: mark changelog <approved-tag>" && git push origin main`.
10. Update `.agents/plans/xp-state.md` to record the final release tag. Once the release is fully completed, halt execution.

## ANTI-PATTERNS
- **Ghost Todos**: Failing to update the `.agents/plans/xp-state.md` status fields as work progresses.
- **Skipping Gates**: Proceeding to Development without Architecture approval, to Release without PR approval, or halting before branch merge confirmation.
- **Unbounded Loops**: Failing to pass the exact failure feedback to the personas when a human checkpoint requests changes.
- **Ad-Hoc Tags**: Creating release tags without reading existing tags from git or validating against the semver regex. Every release tag MUST pass the semver validation gate and human approval before creation.
- **Ad-Hoc Release Notes**: Using generic or ungrounded release notes instead of deriving them from `CHANGELOG.md`. All release notes MUST be sourced from the accumulated `## [Unreleased]` section, filtering out internal developer-only churn so only user-facing changes are published.
- **Bypassing Release Gate**: Proceeding directly to packaging after merge without presenting the release gate to the human. Every merge MUST go through the release gate so the human can decide whether a release is warranted.
