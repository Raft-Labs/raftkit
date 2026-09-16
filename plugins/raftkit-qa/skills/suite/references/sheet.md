# The Sheet — layout, sync, conflicts

## Columns (exact order)

| Column | Holds |
|---|---|
| case ID | the stable sync key, assigned once, never renumbered or reused |
| feature | the feature the case belongs to (cases are grouped by feature) |
| steps | the manual steps |
| data | the test data the steps use |
| expected | the expected result |
| coverage tag | exactly one of `happy` · `edge-case` · `permission` |
| status | `not run` · `pass` · `fail` · `blocked`; new cases default to `not run` |
| owner | `generated` for generated rows; QA writes their name when they add or edit a row |

The skill owns the structure and the IDs; QA owns the values. A regeneration adds rows and proposes changes, never reorders, renames or drops columns, never resets a status QA changed.

## Coverage tags

`happy` the intended path · `edge-case` waiting, empty, error, success confirmation, a limit or a default value (the story template's edge-case rows) · `permission` an access or role boundary. A business rule takes the tag of the path it runs on.

## Case IDs

Assigned once when first written; never renumbered when rows above move; never reused after removal. Distinct prefixes for generated and QA-authored cases, recorded per project. A QA-authored row without an ID gets one on the next run, once.

## Traceability

Every generated case cites the profile or doc fact it came from, in the steps or expected text or an adjacent note. QA-authored cases need no citation.

## Re-run: re-import first, then diff

1. Read every Sheet row. QA's rows and edits are first-class.
2. Regenerate from the current Profile.
3. Diff by case ID:
   - **new** — not in the Sheet → add with `not run`.
   - **unchanged** → leave.
   - **delta** — sources changed a row QA has not touched → propose.
   - **conflict** — sources changed a row QA touched → show both versions; QA picks; nothing else changes the row.

QA-touched means owner is not `generated`, the ID was never generated, or the row differs from generation while still owner `generated` (an unclaimed edit is still an edit). Tiebreak: a `generated`-owned row that differs from the new generation is a delta only when it still matches what the last run wrote and that run is in this chat; otherwise it is a conflict.

## Writes

Batches with a progress line so a large write never looks stalled and an interruption leaves a coherent partial Sheet. Idempotent by case ID: a clean re-run after an access fix never duplicates.

## Success line

```output
Suite: N cases (X generated, Y QA-authored) — Sheet in sync
```

Only after the Sheet reflects the counts.

## Soft cap and split

When the suite can no longer be generated and verified in one run, or one Sheet is no longer navigable, propose a split by feature area into another Sheet for the same project. QA decides. A split is a size decision; batching is a write mechanic.

## Edge and error states

Sheet exists but is empty on a re-run → the draft is a full re-export, flagged as such at the stop; never assume it was emptied on purpose. Sheet unreachable → stop before writing and name which account needs which permission on which Sheet or folder. No Sheets connector → stop and name it.
