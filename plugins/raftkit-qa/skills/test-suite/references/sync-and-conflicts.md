# Sync and conflicts — the core guarantee

Two-way sync between the generated suite and the QA-owned Sheet is the hard part
of this skill, and **conflict safety is the core guarantee**: a regeneration must
never silently overwrite what QA changed. This file defines how a run reconciles
the two sides.

The sync key is the **case ID** — stable across regenerations by the scheme in
`sheet-format.md`. Everything below keys on it.

## The reconciliation order (re-import first, always)

A run never generates onto a blank slate when a Sheet already exists. It reads the
Sheet **first**, then reconciles:

1. **Re-import the Sheet.** Read every row. QA's added rows and QA's edits to
   existing rows are **first-class suite content** — equal in standing to generated
   cases, never discarded, never treated as scratch.
2. **Regenerate from the current profile/docs.** Produce the generated cases the
   sources support now, each traceable to a fact (`sheet-format.md`).
3. **Diff by case ID** into four buckets:
   - **New generated** — a generated case whose ID is not yet in the Sheet → add it
     with the default status (`sheet-format.md`).
   - **Unchanged** — generated content matches the Sheet row → leave it.
   - **Generated change to an untouched row** — the sources changed a case QA has
     **not** edited → propose it as a **delta** for QA to accept.
   - **Generated change to a QA-touched row** — the sources changed a case QA
     **has** edited → a **conflict** (next section). Never an overwrite.

## Conflict rule (QA edits win by default)

> **Provisional pending PRD open question §10.8 (Sheet conflict rules).** The
> default below is the story's own stated policy, shipped as the operative default —
> not a settled resolution. If §10.8 lands a different rule, this is the single
> place to change it.

The default policy:

- **QA edits win by default.** When a generated change collides with a QA-touched
  row, the QA version stands; the generated version does **not** replace it.
- **The generated change becomes a conflict item, not an overwrite.** List the
  conflict with **both versions side by side** — the QA row and the proposed
  generated row — and let QA pick. QA resolving the conflict is the only thing that
  changes the row.
- **Never a silent overwrite.** A QA-touched row is never changed by a run without
  QA choosing it. Silence resolves nothing; the conflict stays listed until QA acts.

"QA-touched" means any row QA added or edited since it was last generated — tracked
by the case ID plus the owner/edit state the Sheet carries, not by guesswork.

## How the delta and conflicts are presented

A regeneration reports, before writing anything back:

- the **new generated** cases it will add,
- the **deltas** on untouched rows it proposes,
- the **conflicts** on QA-touched rows, each with both versions side by side.

QA approves the additions/deltas and resolves the conflicts; only then does the run
write. This is the draft-then-approve gate (`raftkit-core/write-protocol`) applied
to the Sheet.

## Batching large writes (the Waiting edge case)

A large suite is written to the Sheet **in batches, with progress** ("wrote 120 of
300 cases"), so a big generation does not look stalled and a mid-run interruption
leaves a coherent partial Sheet rather than a corrupt one. Batching is a write
mechanic for one Sheet; it is distinct from the **split proposal** (a size decision
about needing a second Sheet) — see `sheet-format.md`.

## Empty and error states

- **Empty — no Sheet yet:** first run creates the Sheet and does a full export.
- **Empty — Sheet exists but has no cases on a re-run:** offer a full re-export
  rather than assuming the suite was intentionally emptied.
- **Empty — no Project Profile:** do not fabricate a suite. Route to
  `raftkit-pm/project-onboarding` to build the profile first (see SKILL.md).
- **Error — Sheet unreachable / permission lost:** name the **exact access fix** —
  which account needs which permission on which Sheet or Drive folder (for example,
  the run's Google account needs edit access to the named Sheet) — not a generic
  failure. Do not partially write; stop and surface the fix so QA can grant access
  and re-run. Idempotency by case ID means a clean re-run after the fix does not
  duplicate cases.
