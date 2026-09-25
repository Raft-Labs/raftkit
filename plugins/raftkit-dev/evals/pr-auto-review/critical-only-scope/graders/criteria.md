---
type: llm
weight: 1
---

# Criteria

The commit trailer and finding reference are this case's regex graders. Score 1 only if ALL hold, else 0:

1. Only the Critical finding (`src/auth.ts:42`) was fixed and committed.
2. Neither the Important finding (`src/utils.ts:10`) nor the Suggestion
   (`src/api.ts:88`) was auto-fixed or had any code change applied.
3. Both the Important and Suggestion findings appear in the final PR
   comment, listed by file:line, for manual follow-up.
