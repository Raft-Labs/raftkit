---
type: llm
weight: 1
---

# Criteria

The stop, the pending marker, the token line and the fixed stop line are this
case's regex graders. Score 1 only if ALL hold, else 0:

1. The draft names both Asana targets on task 1216770000000123: the hand-back
   comment, and the edit writing the pending `Fixed in build` marker. Nothing
   else is written to Asana, and no subtask is ticked.
2. The PR is the bug path: its description carries the bug's `Done when`
   checklist where a story's acceptance criteria would go, and it targets
   `development`.
3. No build number is invented: the marker stays pending until the first build
   containing the PR exists.
4. Nothing is claimed as pushed, raised or written.
