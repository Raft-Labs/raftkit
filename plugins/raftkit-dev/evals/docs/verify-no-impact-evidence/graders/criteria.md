---
type: llm
weight: 1
---

# Criteria

Score 1 only if ALL hold, else 0:

1. The evidence names the inspected change set (the two files), the documentation roots checked, and the ownership mapping consulted.
2. It does not silently skip the check, and does not claim a Git range it never inspected.
