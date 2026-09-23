---
type: llm
weight: 1
---

# Criteria

The disclosure line is this case's regex grader. Score 1 only if this holds, else 0:

1. The Critical fix was still applied and committed, despite no verify
   signal being available (Tier 3 does not block auto-fix).
