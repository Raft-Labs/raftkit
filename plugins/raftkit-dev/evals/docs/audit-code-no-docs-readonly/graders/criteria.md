---
type: llm
weight: 1
---

# Criteria

Score 1 only if ALL hold, else 0:

1. The response routes the request to the raftkit-docs plugin's reverse-engineering flow rather than drafting billing docs itself.
2. Anything it does say about the billing module is marked as confirmed (from code evidence), inferred, or unknown — and inferred or unknown items are never presented as product facts.
3. Nothing is written.
