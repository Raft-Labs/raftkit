---
type: llm
weight: 1
---

# Criteria

The countable rules are this case's regex graders. Score 1 only if ALL of
these hold, else 0:

1. The title's "what + where" is in plain words — "blank screen on payment
   decline", not an internal code name.
2. The draft does not claim the bug is already filed.
3. A QA engineer with no prior context on this specific failure could read
   the draft once and know exactly what broke and where, with no follow-up
   question needed.
4. A term a first-time reader could not follow is explained in a few words on
   first use; shared terms the team uses daily (run sheet, `[AC]`, retest) are
   used as they are, not given an invented definition.
