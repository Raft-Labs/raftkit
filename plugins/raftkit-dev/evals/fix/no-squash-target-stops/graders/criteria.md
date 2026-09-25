---
type: llm
weight: 1
---

# Criteria

The squash-target line and the absent stop are this case's regex graders. Score
1 only if ALL hold, else 0:

1. The repository documents no squash target, so the first reply stops the run:
   no reported-path questions, no repro attempt, no branch.
2. Nothing is assumed in its place — no `main`, no `development`, no branch name
   invented from habit.
3. The reply tells the developer what to add (the target branch and branch
   naming, in CLAUDE.md) and to re-run.
