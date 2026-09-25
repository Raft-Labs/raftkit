# The estimate Sheet

One estimate, one Sheet, never the source list. Every run creates a new Sheet, `<project> estimate — <date>`, uploaded as CSV and converted in the folder the PM named; Drive cannot edit a Sheet in place, so no run does.

| Row | Holds |
|---|---|
| 1 | `Requires founder review — not a client commitment.` |
| 2 | `AI estimate → vetted by <implementing developer> → approved by Nirav or Ashit → only then shared with the client.` |
| 3 | header: feature · FE (h) · BE (h) · QA (h) · total · assumptions |
| 4… | one row per feature, the feature named exactly as the list names it, ranges as low–high, a stated `0` where none |
| last | the list total, with the list-level assumptions |

The skill owns rows 1–3 and the column set; the PM owns the content. A re-run reads the latest earlier Sheet, writes a new dated one and never edits the old one. The stop lists every row that differs from it: new, changed, dropped. A number the PM or developer edited there carries over, and a new estimate that differs from it is shown for the PM to resolve.

Name the source Sheet in the estimate so the two stay traceable. Report the link only after the write lands.

## Shapes without numbers

The watermark still opens them; the chain line is omitted.

```output
Requires founder review — not a client commitment.

One story is raftkit-pm:story's job — ask it to size the story. This skill estimates a whole feature list.
```

```output
Requires founder review — not a client commitment.

The feature list could not be read, so nothing was estimated.
Fix: grant <account> view access to <sheet or document>, then re-run.
```
