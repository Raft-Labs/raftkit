# Output, sign-off, and error states

The exact shape scope-guard emits, how a flagged item clears, and how it stops
when it cannot audit. The three quoted strings below are **fixed** — emit them
verbatim.

## The two lists

Exactly two lists, always these headers, in this order:

```
BEYOND THE STORY
MISSING FROM THE STORY
```

- **BEYOND THE STORY** — one entry per flagged item, **each naming its file(s)**.
  Includes additions that map to no `[AC]`, every Out-of-scope item that
  appears in the diff, and documentation edits that map to neither an `[AC]`
  nor the Gate-1-approved Docs Impact Plan. Blocks the PR until the item is
  **removed** or **explicitly signed off** (sign-off logged, below).
- **MISSING FROM THE STORY** — one entry per uncovered `[AC]`, **quoting the AC
  verbatim**. Blocks the PR until the item is **built** or **explained**.

## Verdict

- **Both lists empty** → pass. Emit the fixed clean-pass line exactly:

  ```
  Scope-guard: clean — 0 beyond, 0 missing
  ```

  and state that the PR is unblocked.
- **Either list non-empty** → the PR is **blocked**. Report both lists with their
  item counts (e.g. "2 beyond, 1 missing") and the per-item clear path.

## Empty diff

An empty diff is not a pass: report that nothing is implemented yet, and
**MISSING lists every `[AC]`** (each quoted). Nothing to put in BEYOND.

## Sign-off log — how a BEYOND item survives

A BEYOND item stays in the diff only with the dev's **explicit** sign-off —
**silence is not approval**. Each sign-off is logged in the run output so it is
auditable later, naming all three:

- **Item** — the flagged addition (and its file(s)).
- **Reason** — why it stays despite having no AC.
- **Dev** — who signed off.

A signed-off item is recorded as signed-off in the output, not silently dropped
from BEYOND — the audit trail shows both that it was flagged and who cleared it.

## Error states — stop, do not audit a partial picture

- **Story unreachable** (Asana connector down, no access, or the task is
  unreachable) → **stop and name the access problem** with scope-guard's own
  fixed line:

  ```
  Can't read the story — check your Asana connector, then retry.
  ```

  (Use `raftkit-core/workflow-constants` for the general connector-check
  guidance, but this line names the *story* — do not reuse the template-worded
  stop string, which would mislead the dev here.) Do not fall back to a
  remembered story or audit against a partial one.
- **Diff unavailable** (detached HEAD or otherwise unusable git state) → stop and
  suggest the **exact git remedy**, e.g.:

  ```
  git status            # confirm the state
  git switch <branch>   # reattach to the story branch
  ```

  Do not audit a partial or empty diff produced by a broken git state.
- **Multi-story branch** → reject and name the collision (see
  `references/audit-method.md`); do not produce a two-list audit.
