---
name: release-packager
description: Use this skill to compile, bundle, or package the completed project into a releasable artifact or distribution archive.
---

# SKILL: Release Packager

This skill encapsulates the packaging stage of the XP lifecycle pipeline. It uses deterministic tools to bundle project source code, assets, or binaries into a release package (e.g., archive zip/tar, executable, APK, IPA, or distribution bundle). It is invoked for both intermediate builds (Phase 3, feature branch) and final release builds (Phase 5, main branch).

## PROCEDURE

1. **Verify Prerequisites:**
   - Ensure the `xp-state.md` plan indicates that the development stage is complete (all backlog tasks are `done`).
   - For a final release build (Phase 5), also verify that PR review is complete.
   - For an intermediate build (Phase 3), PR review is NOT required — the build runs on the feature branch before review.
   - If the required prerequisites are not met, refuse to run.

2. **Determine Packaging / Build Command:**
   - Check `xp-state.md` or the project repository configuration to determine the packaging command / asset bundler.
   - If the caller specifies an explicit build type (`release` or `debug`), use the appropriate variant. If no build type is specified, **default to `release`**.
   - Select the corresponding packaging command variant:
     - Release: Project release script, archive bundler (e.g., zip/tar utility), `flutter build apk --release`, `gradlew assembleRelease`, `npm run build`, etc.
     - Debug: Project debug script or debug build command (e.g., `flutter build apk --debug`, `gradlew assembleDebug`, etc.).

3. **Execute Packaging (S7 Deterministic Tool Bridge):**
   - Execute the selected packaging command using the `run_command` tool.

4. **Verify Output:**
   - Use the `list_dir` or `run_command` (e.g., `ls` / `dir`) tool to verify that the expected output artifact (e.g., `.zip`, `.7z`, `.tar.gz`, `.apk`, `.exe`, `.ipa`) was actually generated in the output directory.
   - If the artifact does not exist, report a build failure and provide the packaging logs.

5. **Report Success:**
   - If the artifact exists, report success to the orchestrator and provide the absolute path to the release package.

## ANTI-PATTERNS
- **Plan-and-Pray**: Do not just run the build command and assume it worked. You MUST verify the output artifact exists on disk.
- **Deployment**: This skill ONLY packages the project. It MUST NOT attempt to deploy the package to an app store, external server, or distribution network.
- **Wrong Build Type**: Do not default to debug builds. The default is ALWAYS `release` unless the caller explicitly specifies `debug`.
