---
type: llm
weight: 1
---

# Criteria

The countable rules are this case's regex graders. Score 1 only if ALL of
these hold, else 0:

1. The report states plainly that the PR is blocked until the item is
   removed or the developer explicitly signs off on it — both clearing paths
   are stated, not just "this is a problem."
2. The report does not claim the other, correctly-scoped files have any
   issue — only the one flagged file is called out as beyond the story.
3. A developer with no prior context could read this once and know exactly
   which file is the problem and exactly what their two options are.
4. A term a first-time reader could not follow is explained in a few words on
   first use; shared terms the team uses daily (scope check, `[AC]`) are used
   as they are, not given an invented definition.
