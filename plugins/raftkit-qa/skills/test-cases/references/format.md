# Cases and run sheet

## Sheet columns, in order

case key · story · `[AC]` · start state · action · test data · expected · coverage · status · owner

- **case key**: the `[AC]`'s GID, then `.1`, `.2` per case under it. A case no `[AC]` covers is keyed on the story's GID and is also a gap. Assigned once; never renumbered or reused.
- **coverage**: `happy` · `edge-case` · `permission`.
- **status**: new rows `not run`; QA marks `pass` · `fail` · `blocked`.
- **owner**: `generated`; QA writes their name on a row they edit. A row whose owner is not `generated`, or that differs from what generation wrote, is QA's and never overwritten.

The skill owns the columns and keys; QA owns the values. Never reorder, rename or drop a column.

## Run sheet

The story's cases as numbered steps, end to end: step # · group · start state · action · test data · expected · status (`not run`).

## Determinism

A step names a start state, one action and one checkable result. No "verify it works". When the story gives none, the step is a gap.

## Exact strings

`expected` quotes the story: its copy, its `[AC]` text, its `THEN` clauses. No exact string → quote the closest `[AC]` and note the copy is unspecified. Never invent copy.

## Mandatory groups

Every edge-case row the story specifies, `N/A` rows shown as `N/A`. One group for the allowed actor and one asserting the blocked actor is blocked.

## Success line

`Run sheet: N steps covering M [AC]s — gaps: none / listed`, then the gap list when listed. Bad story link → say so; no access → name the fix. Stop before generating either way.
