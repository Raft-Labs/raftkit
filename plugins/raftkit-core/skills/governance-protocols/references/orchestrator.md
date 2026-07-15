# Skill: RaftLabs Architectural Task Orchestrator

## Purpose
Enforces the mandatory architectural breakdown of monolithic, long-running tasks into isolated subagents to protect context windows and prevent hallucination loops.

## Execution Workflow

### Step 0: Mandatory Specification Verification
Before building any implementation blueprint or planning subagents:
1. Scan the project workspace for the path `docs/specs/active-feature.md`.
2. Read the markdown content of the spec file. It must contain explicit sections for:
   - Data Schema Changes
   - API Endpoint Definitions
   - Expected Output/Edge Cases
3. **Hard Stop Gate:** If this file is missing, empty, or lacks details, halt execution completely and output:
   "❌ ORCHESTRATION REJECTED: Spec-Driven Development protocol is active. Please populate your feature spec in `docs/specs/active-feature.md` before assigning this task to the AI."

### Step 1: Monolith Evaluation
When the user submits a broad feature request (e.g., adding an API endpoint connected to NeonDB and consuming it in NextJS), instantly halt execution. Do not write code. Analyze the requirements across:
- **Impacted Folders:** Frontend (`/apps/web`, `/components`), Backend (`/src/routes`), Infrastructure (`/sst`).
- **Context Depth:** Schemas or metadata required to make the code execute safely.

### Step 2: The User-Facing Breakdown
Present a structured markdown table to the user detailing your subagent delegation plan. Stop and wait for human confirmation. Use this layout:

| Phase | Subagent Target Name | Scope / Target Files | Target Model | Reason / Dependency |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `db-schema-builder` | `/src/db/schema.ts` | Sonnet | Defines core data types |
| 2 | `hono-api-router` | `/src/routes/api.ts` | Sonnet | Depends on completed Phase 1 schema |
| 3 | `next-ui-view` | `/components/Feature.tsx` | Sonnet | Consumes completed Phase 2 API endpoint |

*Prompt the user:* "I have broken this long-running task into atomic units to prevent code hallucination. May I proceed with spawning background subagents for these phases?"

### Step 3: Headless Subagent Execution with Guardrails
Once the user enters confirmation:
1. Use the `/agents` tool to provision an isolated workspace execution stream for Phase 1.
2. Inject only the specific target files and the narrow sub-prompt context into that subagent. Do not pass the root chat history.
3. **Pre-Flight Enforcement:** The subagent must run local pre-flight checks (e.g., `npm run test`) to confirm its workspace compiles before and after making edits.
4. **Infinite Loop Protection:** If a background subagent loops or tries to self-correct a lint/compiler issue more than 3 times, it must pause, output its usage metrics back to the parent stream, and alert the primary screen:
   "⚠️ SUBAGENT LOOP WARNING: Subagent [Name] has attempted to resolve a compile issue 3 times and is consuming tokens. Pausing for human review. Please run `/agents view [Name]` to inspect."
5. Synthesize completed subagent outputs sequentially inside the main window once they successfully pass all verification gates.
