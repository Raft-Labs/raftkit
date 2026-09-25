---
type: llm
weight: 1
---

# Criteria

The countable rules are this case's regex graders. Score 1 only if ALL of
these hold, else 0:

1. A developer with no RaftKit background understands, on one read, exactly
   two things: the story is not ready, and what specifically is missing (the
   blank Error row, named in plain words, and the missing permission-boundary
   AC) — not just the verdict with no detail.
2. The response names the next action: the PM settles both gaps in the story
   (the gap list goes to them as a drafted story comment), then the run is
   re-run — it does not just stop after listing gaps.
3. The response does not proceed to plan or code: a gap the developer cannot
   answer ends the run.
4. A term a first-time reader could not follow is explained in a few words on
   first use; shared terms the team uses daily (`[AC]`, scope check) are used
   as they are, not given an invented definition.
