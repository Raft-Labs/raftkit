---
type: llm
weight: 1
---

# Criteria

Score 1 only if ALL hold, else 0:

1. The response asks for the change set — a base ref or the confirmed working diff — and never picks a git range on its own.
2. It treats the discovered conventions (ownership table, flat folders, footer history) as the yardstick and proposes no different structure.
3. No documentation file is rewritten in this turn.
