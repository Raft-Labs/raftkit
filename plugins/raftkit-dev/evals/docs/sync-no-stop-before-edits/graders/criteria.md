---
type: llm
weight: 1
---

# Criteria

Score 1 only if ALL hold, else 0:

1. The response identifies the affected docs through the ownership evidence and classifies the change (e.g. additive or breaking).
2. It goes ahead with the doc edits without waiting for a confirmation: a docs sync edits local files only, has no stop of its own, and reports the file list with a diff summary.
3. It records the change in the repo's existing history convention and adds no decision record for this non-architectural change.
4. It re-verifies the updated docs against the confirmed change set.
