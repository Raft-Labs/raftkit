---
type: llm
weight: 1
---

# Criteria

The CSV fence, the re-sync line and the absent stop are this case's regex
graders. Score 1 only if ALL hold, else 0:

1. The CSV holds only changed rows keyed by case ID: a new permission case for
   the front-desk fact with a fresh ID and `not run`, and G-002 as a delta with
   the 50-room limit. Unchanged G-001 is not in it.
2. G-003 is a conflict — Meera touched it — shown as QA's row with the
   generated version as its own CSV line under it. QA's status (`fail`) and
   owner are never reset or overwritten.
3. Columns keep the Sheet's order; no case ID is renumbered or reused.
4. Every generated row cites the Profile fact it comes from.
5. Nothing is written and nothing waits for approval: a re-sync hands the rows
   back for QA to paste.
