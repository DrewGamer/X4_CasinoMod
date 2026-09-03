# Genesis Refactor Plan: XP Orchestrator & Developer TDD Rigor

## 1. Intent & Scope

### Problem Statement
In recent feature development, two critical architectural anti-patterns emerged:
1. **Orchestrator Drift / DIY Research**: The `xp-orchestrator` performed open-ended codebase investigations, grepped source files, and diagnosed bugs directly in the orchestrator thread, contaminating its context window and degrading its capacity to govern Git state, human gates, and phase transitions.
2. **Test-After-Code / Vacuous Tests**: The `xp-developer` persona stated "Write the code and tests required to fulfill the active task" and "practice TDD where applicable". This primed the model to write code first and tests second (or skip tests entirely), bypassing the critical RED phase (observing failure before implementation).

### Goals & Boundaries
- **Strict Role Bounding**: Restrict `xp-orchestrator` to a pure coordinator and conductor. Forbid it from reading application source code, running source grep, or diagnosing bugs in the parent thread.
- **Subagent Research Delegation**: Explicitly define pathways to dispatch `research` subagents for codebase exploration, documentation analysis, and log triage, returning concise finding receipts to the orchestrator.
- **Strict Red-Green-Refactor TDD**: Restructure `xp-developer` to mandate the Red -> Green -> Refactor cycle, requiring the developer to execute the project's configured test runner (from `xp-state.md`) to witness test failure before writing implementation code.
- **100% Project Agnostic**: Ensure zero domain coupling (no references to specific games, languages, frameworks, or engines). Configuration is read dynamically from `.agents/plans/xp-state.md`.

---

## 2. Component Diagram (Mermaid)

```mermaid
flowchart TD
    O{xp-orchestrator}
    T[(xp-state.template.md)]
    S[(xp-state.md)]
    
    A((xp-architect))
    D((xp-developer))
    R((research-subagent))
    
    HC[human-checkpoint]
    EM[environment-manager]
    RP[release-packager]
    
    GIT[(git / gh CLI)]
    TEST[(Project Test Runner<br/>S7 Tool Bridge)]
    BUILD[(Project Build Script<br/>S7 Tool Bridge)]
    
    O --> T
    O <--> S
    O --> HC
    O --> EM
    O --> RP
    O --> GIT
    
    O -. spawns child thread .-> A
    O -. spawns child thread .-> R
    O -. spawns child thread .-> D
    
    D --> TEST
    RP --> BUILD
```

---

## 3. Thread / Sequence Diagram (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    participant Human as Operator (Human)
    participant Orch as xp-orchestrator (Parent Thread)
    participant Res as research (Child Thread)
    participant Dev as xp-developer (Child Thread)
    participant Tool as Test Runner / CLI (S7 Bridge)
    
    Note over Orch: Phase 0 & 1: Architecture & Gates
    Orch->>Human: Checkpoint: Architecture / Feature Approval
    Human-->>Orch: Approved
    
    Note over Orch: Phase 2: XP Development Loop
    alt Ambiguous Task or Codebase Research Required
        Orch->>Res: Spawn research subagent (query, scope, files)
        Note over Res: Read-only exploration & doc analysis
        Res-->>Orch: Concise findings brief (no raw code dump)
    end
    
    Orch->>Dev: Spawn xp-developer (active task + constraints)
    
    Note over Dev: Strict TDD Phase 1: RED
    Dev->>Tool: Write failing test & run test runner
    Tool-->>Dev: Witness expected failure (RED verified)
    
    Note over Dev: Strict TDD Phase 2: GREEN
    Dev->>Tool: Write minimal code & run test runner
    Tool-->>Dev: Tests pass (GREEN verified)
    
    Note over Dev: Strict TDD Phase 3: REFACTOR
    Dev->>Tool: Clean code/tests & verify tests remain green
    Tool-->>Dev: All tests green
    
    Dev-->>Orch: Task receipt (Red/Green proof, diff, git commit)
    Note over Orch: Update xp-state.md status
    
    Note over Orch: Phase 3 & 4: Continuous Packaging & Manual Testing
    Orch->>Human: Checkpoint: Manual verification of artifact
    alt Issues Found in Testing
        Human-->>Orch: Bug report / unexpected behavior
        Note over Orch: NEVER do DIY research in parent thread!
        Orch->>Dev: Dispatch bug reproduction brief
        Note over Dev: Write reproducing test (RED) -> fix (GREEN)
    else Testing Approved
        Human-->>Orch: Approved -> Proceed to Phase 5 (Release Gate)
    end
```

---

## 4. Dependency Graph & Composition Decisions (Step 3.5)

```mermaid
flowchart LR
    Orch[xp-orchestrator] -- LOCAL SIBLING --> Arch[xp-architect]
    Orch -- LOCAL SIBLING --> Dev[xp-developer]
    Orch -- LOCAL SIBLING --> Pack[release-packager]
    Orch -- LOCAL SIBLING --> Env[environment-manager]
    Orch -- LOCAL SIBLING --> Gate[human-checkpoint]
    Orch -- INLINE ASSET --> StateTmpl[assets/xp-state.template.md]
    Orch -- EXTERNAL SUBAGENT --> ResAgent[research subagent]
```

### Module Composition Table
| Module | Composition Mode | Rationale |
|---|---|---|
| `xp-orchestrator` | LOCAL SIBLING | Primary workflow manager in `.agents/skills/`, synced to `DrewGamer/agent-xp-workflow`. |
| `xp-developer` | LOCAL SIBLING | Core XP persona in `.agents/personas/`, synced to `DrewGamer/agent-xp-workflow`. |
| `xp-architect` | LOCAL SIBLING | Systems design persona in `.agents/personas/`. |
| `research` | EXTERNAL SUBAGENT | Standard environment read-only subagent for research/exploration without parent context pollution. |
| `assets/xp-state.template.md` | INLINE ASSET | Template asset owned by `xp-orchestrator`. |

---

## 5. Separation of Concerns & Compliance (Step 4 & 5)

### Anti-Patterns Prevented
1. **DIY Research / Orchestrator Drift**: Orchestrator reading project source code, running source grep, or diagnosing bugs directly in the parent thread.
2. **Context Window Exhaustion**: Filling the orchestrator thread with noisy source files and logs, degrading git state tracking.
3. **Vacuous Tests / Test-After-Code**: Implementing code before writing failing tests, or asserting passing status without witnessing the initial failure.
4. **Project Specificity Leakage**: Introducing language-, engine-, or domain-specific hardcodings into transferable skills and personas.

### Compliance Checklist
- [x] Canonical name: `xp-orchestrator` (matches directory).
- [x] Body size: SKILL.md <= 500 lines.
- [x] Description: <= 1024 chars, imperative phrasing, intent-first.
- [x] Pure project-agnostic design (test runner and build commands sourced from `xp-state.md`).
- [x] ASCII only.

---

## 6. Token Economics & Cost Projection (Step 3.2)

- **Stance**: `balanced`
- **Prefix Design**: Pure coordinator has a lean context footprint; does not ingest project source code.
- **Child Isolation**:
  - `research` subagent handles multi-file lookups in an isolated child thread, returning a 200–500 token synthesis.
  - `xp-developer` executes in an isolated child thread per task, preventing task accumulation.
- **Observed Delta**: Saves ~15k–30k tokens of raw file inspection per debugging cycle in the parent thread.

---

## 7. Action Plan (Todos)

1. [x] Update [.agents/personas/xp-developer.md](file:///C:/Projects/X4_CasinoMod/.agents/personas/xp-developer.md):
   - Replace "Write the code and tests" with explicit Red-Green-Refactor sequence.
   - Mandate executing the project's configured test runner to verify RED before writing implementation.
   - Define handling for declarative/non-unit-testable assets (static analysis / schema validation).
   - Add anti-patterns: `Vacuous Tests / Test-After-Code`, `Skipping the Red Phase`.
2. [x] Update [.agents/skills/xp-orchestrator/SKILL.md](file:///C:/Projects/X4_CasinoMod/.agents/skills/xp-orchestrator/SKILL.md):
   - Add Pure Coordinator Mandate in Overview & Lens.
   - Forbid reading application source files, grepping codebase, or diagnosing bugs in parent thread.
   - Add Research Delegation step: dispatch `research` subagent for codebase queries or documentation surveys.
   - Update Phase 2 to verify TDD receipt (Red -> Green execution proof) from developer.
   - Update Phase 4 (Manual Testing Loop): forward human bug reports directly to `xp-developer` (with reproducing test requirement) or `research` without parent thread DIY diagnosis.
   - Add Anti-Patterns: `DIY Research / Orchestrator Drift`, `Context Exhaustion`.
3. [x] Validate both files against line budgets, project independence, and markdown syntax.
