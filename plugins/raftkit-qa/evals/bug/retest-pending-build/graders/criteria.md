---
type: llm
weight: 1
---

# Criteria

The gate line and the absent stop are this case's regex graders. Score 1 only
if ALL hold, else 0:

1. The pending marker counts as no build: the run never guesses one (build 214,
   "the latest staging build") or tests against a build nobody named.
2. The run ends at the gate: no pass list, no retest comment, no tag, and no
   further fetch.
3. The reply makes clear who acts next: the build containing PR #512 is filled
   in, or named in the hand-back, and the bug is handed back again.
