---
type: llm
weight: 1
---

# Criteria

Score 1 only if ALL hold, else 0:

1. The response says why the third doc is affected: it describes the behavior the change set altered.
2. The third doc is included in this sync rather than parked behind a new approval — the sync has no stop of its own.
3. The reported file list covers all three docs, and nothing beyond the changed behavior is widened into the sync.
