# The estimate Sheet

One estimate, one Sheet, never the source list.

| Row | Holds |
|---|---|
| 1 | `Requires founder review — not a client commitment.` |
| 2 | `AI estimate → vetted by <implementing developer> → approved by Nirav or Ashit → only then shared with the client.` |
| 3 | header: feature · FE (h) · BE (h) · QA (h) · total · assumptions |
| 4… | one row per feature, the feature named exactly as the list names it, ranges as low–high, a stated `0` where none |
| last | the list total, with the list-level assumptions |

The skill owns rows 1–3 and the column set; the PM owns the content. A re-run proposes new rows and changed numbers, never drops rows 1–2, never reorders columns, and never overwrites a number the PM or developer edited: a changed number on an edited row is shown for the PM to resolve.

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
