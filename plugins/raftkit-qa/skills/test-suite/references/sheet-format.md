# Sheet format — the canonical layout

The Google Sheet **is** the design: its layout is the whole UI QA sees. This file
is the single source of every fixed string the skill must emit verbatim — columns,
coverage tags, status values, the case-ID scheme, the success line, and the
soft-cap heuristic. Nothing here is paraphrased elsewhere; other files point back
to this one so the strings never drift.

## Fixed columns (exact order, verbatim)

One Sheet, one header row, these eight columns in this order:

| Column | Holds |
|---|---|
| case ID | the stable sync key (see below) — assigned once, never reused or renumbered |
| feature | the feature the case belongs to (cases are grouped by feature) |
| steps | the manual steps QA performs |
| data | the test data the steps use |
| expected | the expected result |
| coverage tag | exactly one of the coverage tags below — mandatory on every case |
| status | one of the status values below; new cases default to `not run` |
| owner | who owns the case (QA who authored or last edited it) |

The skill **owns the structure** — the column set, their order, and the case IDs.
QA **owns the content** — the values in the rows. A regeneration may add rows and
propose changes, but it never reorders, renames, or drops these columns.

## Coverage tags (mandatory, one per case)

Every case carries exactly one coverage tag:

- `happy` — the intended, valid path.
- `WEESLD` — an edge case in the WEESLD frame (Waiting, Empty, Error, Success,
  Limits, Default values).
- `permission` — an access-control / role-boundary case.

A generated case with no coverage tag is not emitted — the tag is part of what
makes a case complete.

## Status values

`not run` · `pass` · `fail` · `blocked`. **New cases default to `not run`.** The
skill sets the default on generation; QA changes it as they test. A regeneration
never resets a status QA has changed.

## Case-ID scheme (the sync key)

The case ID is how a row in the Sheet maps to a case in the suite across every
regeneration — it is the sync key, so it must be **stable**:

- Assigned once, when the case is first written, and **never renumbered** on any
  later run — even if cases above it are removed or reordered.
- **Never reused.** A removed case's ID is retired, not handed to a new case.
- Distinct prefixes for the two origins so provenance is readable at a glance —
  e.g. a generated-case prefix and a QA-authored-case prefix — with the operative
  prefixes recorded per project, not hardcoded here.
- QA-authored rows (added directly in the Sheet) get an ID on the next run if they
  lack one; that assignment, too, is once-and-stable.

Stability is what lets a re-run tell "the same case, changed" from "a new case",
which is the whole basis of the delta and conflict logic in
`sync-and-conflicts.md`.

## Traceability

Every **generated** case is traceable to the profile/doc fact it came from — the
citation travels with the case (in the steps/expected text or an adjacent note),
never dropped. A generated case that cannot cite a fact is not emitted. QA-authored
cases need no citation; they are first-class on QA's authority.

## Success line (verbatim)

On a completed sync, report exactly:

```
Suite: N cases (X generated, Y QA-authored) — Sheet in sync
```

where `N = X + Y`. Emit it only when the Sheet actually reflects the reported
counts — never as an optimistic guess before the write lands.

## Soft-cap and the split proposal (distinct from batching)

**One project per Sheet** is a hard rule — never merge two projects' suites into
one Sheet.

The suite size is **soft-capped**, not hard-limited. The operative heuristic: the
cap is the point where the suite can no longer be **reliably generated and verified
in a single run**, or no longer stays **navigable as one Sheet**. Past that point,
propose a **split by feature area** into an additional Sheet for the same project —
propose it, let QA decide, never split silently. Treat the threshold as a parameter
with that single-run generate-and-verify budget as its default; do not assert a
fixed case count the sources do not give.

This is **not** batching. Batching (see `sync-and-conflicts.md`) is a write
mechanic — a large suite is written to one Sheet in batches with progress. The
split proposal is a size decision — the suite has grown past one navigable Sheet
and should become two. One is about *how* the write happens; the other is about
*how many Sheets* the project needs.
