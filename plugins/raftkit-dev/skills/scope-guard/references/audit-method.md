# Audit method — mapping the diff to the story

How scope-guard turns a branch diff and a story's ACs into the two lists. The
method is deterministic and fail-closed: when in doubt, flag.

## Inputs

- The story's `[AC]` subtasks (the pass list) and its "Out of scope / non-goals"
  section (the hard exclusion list) — both from the live Asana fetch this run.
  Match the exclusion section on its heading, not a section number; the template's
  numbering is not stable (merged-template decision, still open).
- The **Design Approach decision rows and the decomposition table** from the live
  story's spec at `spec_path` (read live from
  `raftkit-core/governance-protocols`; default `docs/specs/active-feature.md` —
  never hardcoded). The decision numbers and their **Phases** column are what the
  fourth mapping surface below joins against. No spec, or a spec with no
  `## Design Approach` section, is a **stale-spec stop** — not a zero-decision
  pass.
- The branch diff against the **merge-base with the PR base branch**.

## Anchoring the diff

Fetch the base branch first, then compute the merge-base against the freshly
fetched ref and diff from there to the branch tip:

```
git fetch origin <base-branch>
git diff "$(git merge-base FETCH_HEAD HEAD)" HEAD
```

`<base-branch>` is the branch the PR will target. Fetching first and anchoring on
`FETCH_HEAD` is exactly what the repo's `scripts/validate.sh` version gate does —
so the audit sees exactly the branch's own changes and never blames changes that
landed on the base after the branch diverged. Never diff against a stale local
base ref.

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
2. Does it match a **permalink-cited Gate-0 clarification**
   (`implement/references/clarification.md`)? The permalink to the story's
   Decision Log comment must be supplied with the run — a clarification asserted
   only in chat, with no permalink, does not count and the item falls through to
   the next check.
3. Does it implement a **Gate-1-approved Design Approach decision**
   (`implement/references/design-approach.md`)? A hunk is admitted through this
   surface only when **both** hold:
   - the decision names the hunk's **phase** in the decomposition table (the
     join key), and
   - the hunk is a **pure relocation or re-pointing of code that already maps
     to an `[AC]`** — it carries that AC with it. There is no "adds behaviour"
     form: a hunk that introduces new behaviour, a new rule, a new field, or a
     new surface is not admitted here even when a decision names its phase —
     that is scope, and belongs back at Gate 1.
   A decision not present on the live story's spec, or one approved **after**
   this audit's diff was already open, does not admit the hunk — this surface
   is never back-dated at Gate 2; approval must predate the code.
4. Does it match an item in the story's **Out-of-scope** list? If yes → it is an
   **automatic BEYOND flag**. Out-of-scope items appearing in the diff are a fail
   condition, not a judgment call.
5. Otherwise — it maps to no AC, no cited clarification, no approved Design
   Approach decision, and no plan → **BEYOND** (fail-closed default).

Then walk the other direction: for every `[AC]`, is there a corresponding change
or test in the diff? An AC with none → **MISSING**. And for every Gate-1-approved
Design Approach decision, is there a corresponding change in the diff? A
decision with none → **MISSING, quoted by its decision number** (e.g. "D2 — no
corresponding change found").

## Documentation edits map like code

Documentation changes in the diff follow the same fail-closed mapping, with one
extra pass list: a docs edit is in scope when it maps to an `[AC]` **or** to an
item on the story's Gate-1-approved **Docs Impact Plan** (the plan `implement`
carried through Gate 1). An unmapped docs edit lands in **BEYOND** for a human
call — regenerated churn and "while we were in there" rewrites included — each
named with its files. And when the approved Docs Impact Plan requires docs for
an AC, an AC whose required doc is untouched counts toward **MISSING**. This is
presence/absence against the plan only — the audit is **not** a docs-quality
reviewer: wording, structure, and style stay with the docs skill's own
verification and the human reviewer.

## Fail-closed default

An item that cannot be confidently mapped to an AC does **not** get the benefit
of the doubt — it lands in **BEYOND** for a human to call. A silent pass on an
unmappable change is exactly the scope creep this gate exists to catch. Flagging
a false positive costs a sign-off line; missing a real addition costs a release.

## What this method never does

- It never judges code quality — only presence/absence against the ACs.
- It never removes or edits code — it only classifies and reports.
- It never audits against a remembered story or a stale base ref.
- It never admits a Design Approach decision that was approved after the diff
  it is meant to admit was already open — the fourth surface is never
  back-dated.

## Incident branch (bounded; activated only by the handoff)

When invoked from an Incident PR Handoff (never in ordinary story mode),
scope-guard audits the incident diff against the handoff's **explicit
containment scope** instead of a story's `[AC]`s: `BEYOND` lists any change
outside the containment scope, and `MISSING` flags an absent permanent
regression test. This branch is reachable **only by the handoff** — story-mode
behaviour (diff-vs-`[AC]`, Out-of-scope auto-BEYOND, merge-base anchor,
fail-closed) is **unchanged** and proven so by the existing suite. Incident
scope-audit evidence is SHA-bound to the inspected containment change set.
