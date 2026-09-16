# Run-sheet format

## Step table (fixed columns, in order)

| Field | Holds |
|---|---|
| step # | sequential, end to end |
| group | the scenario, `[AC]`, edge-case row or permission boundary the step covers |
| start state | the named test account and data the step begins from |
| action | one action |
| test data | the exact data the action uses |
| expected | the story's own wording, verbatim |
| status | `not run` by default; QA marks `pass` · `fail` · `blocked` |

## Determinism

No "verify it works" or "check the page". A step names a start state, one action and one checkable result. When the story gives none, the step is a gap, not a vague line.

## Exact strings

`expected` quotes the story: its copy, its `[AC]` text, its `THEN` clauses. When the story gives no exact string, quote the closest `[AC]` or `THEN` and note the copy is unspecified. Never invent copy.

## Mandatory groups

- One group per edge-case row the story specifies; a row marked `N/A` appears as `N/A` so the sheet shows it was considered.
- One group exercising the allowed actor and one asserting the blocked actor is blocked, from the story's "who is allowed / not allowed" field.

Coverage tags match the suite: `happy` · `edge-case` · `permission`.

## Success line

```output
Run sheet: N steps covering M [AC]s — gaps: none / listed
```

`N` steps, `M` `[AC]`s covered by at least one step. `gaps: listed` when the gap list is non-empty, followed by the list, named for QA and the PM.

## Story unreachable

Bad link or GID → say the link is bad; no access → say access is the problem and name the fix. Stop before generating either way.
