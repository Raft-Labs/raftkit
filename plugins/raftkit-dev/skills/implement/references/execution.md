# Execution — spec, baseline, phases, post-edit gates

Everything between Gate 1 approval and Gate 2. The order is fixed: spec present →
green baseline → branch → test-first phases → post-edit layers. Each step below
is a hard requirement, not a suggestion.

## No spec, no code

Coding cannot begin until the plan approved at Gate 1 is written to the spec file
at `spec_path` (read live from `governance-protocols`; default
`docs/specs/active-feature.md`). The spec derives from the approved story + plan;
the **story stays the single source of truth** behind it.

If the spec file is absent at **any** point after Gate 1 — before the first edit,
or if it goes missing mid-run — stop with the governance pack's verbatim string:

```
❌ ORCHESTRATION REJECTED
```

Reproduce that string from the installed pack (it carries the `spec_path` in its
message); never re-author it and never proceed to edit code without the spec.

## Pre-edit baseline (hard stop)

Before touching any code, run the repo's build/typecheck. **A failing baseline
blocks all edits.** Do not touch feature code; switch to fixing the baseline
first, and surface the failing command's output verbatim so the dev sees exactly
what failed. Only a green baseline unlocks the phases. This is a hard failure
policy — a broken baseline hides which failures the new work caused.

## Branch

Branch per the release-train conventions (`raftkit-core` release model): a
`feature/*` branch, one story per branch, name from the story GID + slug. Repo
docs override the defaults. (The squash target is resolved later by the `pr`
skill, not here.)

## Phases — scoped subagents, test-first

Execute the decomposition table one phase at a time.

- **Narrow context only.** Each phase subagent receives **only its phase's files
  and its sub-prompt — never the root chat history.** Context hygiene between
  phases is the point: a subagent that sees the whole conversation drifts.
- **Model per phase** from the table; **Sonnet is the default workhorse.**
- **Test-first (TDD is mandatory).** Each phase starts **red**: write the failing
  tests derived from the phase's `[AC]`s, then write only the code that turns them
  **green**. `[AC]`s map **1:1 to tests** — one acceptance criterion, one test (or
  named test group) that proves it.
- **Small logical commits** as each phase goes green — conventional-commit titles,
  one concern per commit.
- **Loop protection.** If a subagent fails to self-fix a compile/lint/test error
  after **3 attempts**, it **pauses** — it does not keep burning attempts. Report
  token/cost usage and alert the dev with the governance pack's verbatim string:

  ```
  ⚠️ SUBAGENT LOOP WARNING
  ```

  Reproduce it from the pack; do not re-author it. The dev decides how to proceed.

## Progress streaming

Long phases stream progress so the dev is never staring at silence: report
**phase n of m** and the **tests red/green count** as each phase moves — the
story's "Waiting" edge case, made visible.

## Post-edit gates (all green before Gate 2)

After every phase is green, run these in order — each must pass before the next:

1. **`raftkit-dev/simplify`** — the code-quality simplify pass.
2. **`security-guidance`** — the security check.
3. **Lint + the full test suite** — green, not just the phase tests.

Only when all three pass does the run reach **Gate 2** (`references/gates.md`).
