---
name: docs
description: Check whether a change set leaves the repository's documentation accurate, and sync the docs it touches — "do the docs still match the code?", "sync the docs for this story", "are the docs done for this change?". Discovers the repo's own documentation system, never forces one. Designing docs from scratch is the raftkit-docs plugin.
user-invocable: true
---

# docs

One question, answered with evidence: does this change set leave the docs accurate? `raftkit-core:rules` apply. `implement` and `fix` call this once, on the final diff.

## Run

1. **Discover** the repository's own documentation system with `scripts/audit-docs.mjs`: roots, convention, indexes, ownership mapping, history convention. The result holds for the whole run; never derive it twice. Conflicting signals are reported, and the run asks which convention is authoritative rather than picking one.
2. **Take the change set explicitly** — a base ref, or the confirmed working diff. Never choose a git range silently. No change set → report `not evaluated — no change set provided`.
3. **Map** each changed file to the docs that own it, through the discovered mapping, expanding by change type: a schema change reaches its schema doc, the screens and APIs that use it, and any diagram that depicts it.
4. **Report one of three outcomes**, each with its evidence:

```output
Docs: not impacted — <reason>
Inspected change set: <files> (<source, with SHAs when git-resolved>)
Documentation roots: <roots>
Ownership evidence: <the mapping source(s) consulted>
```

```output
Docs: updated and verified — <n> file(s), history recorded
```

```output
Docs: no recognized documentation convention in this repo — nothing to check.
```

The third is `validate-docs.mjs` exit 2 for an unmapped repo. It is a real outcome, not a failure: a repo with no docs system never blocks a story.

5. **Sync, when docs are impacted**: update only the owned docs, match each one's existing style and depth, record the change in the repo's own history convention, regenerate any diagram whose subject changed, and re-verify with `scripts/validate-docs.mjs` scoped to the change set. An architectural change adds a decision record in the repo's own seam; routine edits add no ceremony. If the update reveals docs beyond the mapped set, say so and include them in the stop.
6. **Stop once** before any doc is written, showing the file list and the diff summary. A run that only reports parity writes nothing and has no stop.

## Boundaries

Docs churn that maps to no acceptance criterion and no proven inconsistency is reported as an observation, never written into the change set. This skill writes no Asana task and no Sheet. Everything stays inside the repository root: no out-of-root symlink is followed, no secret value is read or printed, and temporary files are cleaned up. Designing, generating or reverse-engineering documentation is `raftkit-docs`.
