---
type: llm
weight: 1
---

# Criteria

The template line, the absent stop and the absent story shape are this case's
regex graders. Score 1 only if ALL hold, else 0:

1. No story artifact is produced — no offline draft "to push later" in the
   house format, whether from memory, a prior session, repo files or any cache.
2. The reply may offer to keep the PM's own notes exactly as they give them,
   but never shapes them into a story, its sections or `[AC]`s.
3. The reply ends on the next action: reconnect, then re-run the story skill.
