# Audit method — mapping the diff to the story

How scope-guard turns a branch diff and a story's ACs into the two lists. The
method is deterministic and fail-closed: when in doubt, flag.

## Inputs

- The story's `[AC]` subtasks (the pass list) and its "Out of scope / non-goals"
  section (the hard exclusion list) — both from the live Asana fetch this run.
  Match the exclusion section on its heading, not a section number; the template's
  numbering is not stable (merged-template decision, still open).
- The branch diff against the **merge-base with the PR base branch**.

## Anchoring the diff

Compute the merge-base of the branch and the PR base branch, then diff from
there to the branch tip:

```
git diff "$(git merge-base <base-branch> HEAD)" HEAD
```

`<base-branch>` is the branch the PR will target. This is the same anchor the
repo's `scripts/validate.sh` version gate uses — so the audit sees exactly the
branch's own changes and never blames changes that landed on the base after the
branch diverged. Never diff against a stale local base ref.

## Multi-story branch — reject, don't audit

The release train is 1 branch = 1 story. Before auditing, confirm the branch
carries a single story's work (the branch name and the changed areas trace to one
story). If it carries more than one, **reject the run**, name the collision, and
stop — a two-list audit against one story would mislabel the other story's
changes as BEYOND. Split the branch first, then re-run.

## Mapping each changed item

Walk the diff **file-group by file-group** (large diffs report progress per group
so nothing is skipped). For every changed item — a feature, field, screen, file,
or hunk — decide:

1. Does it map to at least one `[AC]`? If yes, it is in scope — no flag.
2. Does it match an item in the story's **Out-of-scope** list? If yes → it is an
   **automatic BEYOND flag**. Out-of-scope items appearing in the diff are a fail
   condition, not a judgment call.
3. Otherwise — it maps to no AC → **BEYOND** (fail-closed default).

Then walk the other direction: for every `[AC]`, is there a corresponding change
or test in the diff? An AC with none → **MISSING**.

## Fail-closed default

An item that cannot be confidently mapped to an AC does **not** get the benefit
of the doubt — it lands in **BEYOND** for a human to call. A silent pass on an
unmappable change is exactly the scope creep this gate exists to catch. Flagging
a false positive costs a sign-off line; missing a real addition costs a release.

## What this method never does

- It never judges code quality — only presence/absence against the ACs.
- It never removes or edits code — it only classifies and reports.
- It never audits against a remembered story or a stale base ref.
