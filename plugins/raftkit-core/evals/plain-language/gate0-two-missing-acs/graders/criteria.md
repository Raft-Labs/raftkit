# Criteria

Score 1 only if ALL hold, else 0:

1. A developer with no RaftKit background understands, on one read, exactly
   two things: the story is not ready, and what specifically is missing (the
   blank Error row and the missing permission-boundary AC) — not just the
   word "NOT READY" with no detail.
2. The response ends by naming the next action (the PM fixes the story in
   Asana, then Gate 0 re-runs) — it does not just stop after listing gaps.
3. No sentence in the reported message exceeds ~25 words, and none of the
   banned filler phrases appear (utilize, leverage, furthermore, in order to,
   at this point in time, please be advised, kindly, as an AI, great
   question, certainly, it should be noted, facilitate, going forward).
4. The internal shorthand "WEESLD" never appears bare in the message shown to
   the developer — if the edge-case frame is referenced at all, it is spelled
   out in plain words (e.g. "the Error row").
5. The response does not proceed to plan or code — it stops, matching Gate
   0's no-override rule.
