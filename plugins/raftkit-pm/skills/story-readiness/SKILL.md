---
name: story-readiness
description: This skill should be used when a RaftLabs PM wants to check whether a story is ready to hand to a developer — e.g. "is this story ready?", "run the readiness gate on this task", "audit this story against the template", "Definition-of-Ready check", or before handing any story to the dev plugin. Fetches the live Feature Template and the story from Asana, audits the story's completeness against it, and returns a binary PASS / NOT READY verdict with an actionable gap list. It is strictly read-only — it never edits or fixes the story.
user-invocable: true
---

# story-readiness

The Definition-of-Ready gate. Audit one story against the **live** User Story
Template and return an objective verdict — **PASS** or **NOT READY** — plus, when
not ready, a gap list precise enough for the PM to fix without re-reading the
template. The story is the contract (PRD §7.1); a story with unanswered WEESLD
rows or missing copy ships bugs by design. This gate is cheap; the bugs aren't.

This is the inverse of [user-story](../user-story/SKILL.md): that skill *writes* a
template-perfect story; this one *audits* one. It is designed to be reused as the
dev-side Gate 0 that the planned `raftkit-dev · implement` skill (M3, not yet
built) will run before a dev starts — so the same story passes the same gate on
both sides. Building that dev-side enforcement is out of scope here.

## The two rules that govern everything

- **Read-only.** This skill never writes, edits, fixes, or re-files anything. The
  audited story (and its subtasks) must be byte-identical after the run. Fixing a
  gap is the PM's job, not the gate's.
- **Fail closed.** The verdict is binary — **PASS** or **NOT READY**, never "mostly
  ready". Anything you cannot assess — an unreadable field, an ambiguous section, an
  inaccessible task — is **NOT READY**, never a pass. Unknown compliance fails the
  gate; a gate that guesses "probably fine" is worse than no gate.

## Inputs

1. **The story** — a task link or GID. If none is given, ask for one.
2. Nothing else. The checklist itself comes from the live template (below), not
   from the caller.

## Run flow

1. **Resolve constants and fetch the live template.** Get the workspace GID and the
   Feature Template GID from `raftkit-core/workflow-constants`, then fetch the
   template task **live** via the Asana connector — every run, never from memory or
   this repo. The freshly fetched template is the sole authority for what a complete
   story looks like this run (its section list, its WEESLD rows, its required
   fields). If the template cannot be read, stop with the exact `workflow-constants`
   message — do **not** fall back to a remembered checklist.

2. **Fetch the story and all its subtasks** via the Asana connector, from the given
   link or GID. Handle the failure states before auditing:
   - **Bad link / invalid GID** (the task does not exist / the identifier is
     malformed) → report exactly that it is a bad link and name the fix ("check the
     task URL / GID"). This is distinct from the next case.
   - **No access** (the task exists but the connector is denied) → report exactly
     that it is an access problem and name the fix ("you don't have access to this
     task — request access or check the connector"). Distinguishing the two is
     required: the fix differs.
   - **Empty description** (the task has no story body) → **NOT READY** with the
     message: *"the task description is empty — generate the story first"*. Do not
     attempt to audit an empty story.

3. **Derive the checklist from the live template, then audit.** Build the
   Definition-of-Ready checklist from the template's own structure fetched in step 1
   — its sections, its WEESLD rows, its required fields — so that when the template
   evolves the gate evolves with it. Then audit the story against it per
   `references/readiness-checklist.md`. Parse robustly (Asana stories are
   hand-authored): match `[AC]` subtasks by leading token, match sections by number
   and meaning not punctuation, and expect the template's intentional numbering gap.

4. **Emit the verdict** in the exact shape defined in
   `references/readiness-checklist.md` (the single source for the verdict strings):
   - **PASS** → a one-line coverage summary (scenarios, `[AC]`s, WEESLD complete).
   - **NOT READY** → the gap list: one line per gap, each naming the **section** and
     **exactly what is missing**, actionable without re-reading the template.

## Guardrails

- **No auto-fix.** Never edit, generate, or suggest-then-write a correction into the
  story. Report the gaps; the PM (or the `user-story` skill) fixes them.
- **No product-sense judgment.** The gate audits *completeness* — whether the
  contract is fully specified — not whether the feature is a good idea. A complete
  story for a questionable feature still PASSes.
- **One story per run.** An epic is audited sub-story by sub-story; say so rather
  than blending several stories into one verdict.
- **No cached template.** The checklist is derived from the live fetch, so a
  template change in Asana takes effect the same day with no plugin release.
- **Escalate to founders** (`raftkit-core/house-rules`) on budget, contracts,
  relationship risk, or anything that reads as a client commitment — the gate flags,
  it never decides these.

## Reference file

- **`references/readiness-checklist.md`** — the Definition-of-Ready rules (what makes
  each section and each `[AC]` complete), the five gap types this gate must catch,
  the exact gap-line and PASS-summary formats, and the parsing-robustness rules.
