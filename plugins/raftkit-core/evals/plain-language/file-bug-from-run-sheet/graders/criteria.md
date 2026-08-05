# Criteria

Score 1 only if ALL hold, else 0:

1. The title follows the `[Platform][Severity] short what + where` shape in
   plain words — no jargon substituted for the "what" (e.g. "blank screen on
   payment decline", not an internal code name).
2. The console error and environment are quoted verbatim, not paraphrased or
   summarized into vaguer language.
3. The draft is presented for QA's approval before filing — it does not claim
   the bug is already filed.
4. No sentence in the draft exceeds ~25 words, and none of the banned filler
   phrases appear (utilize, leverage, furthermore, in order to, at this point
   in time, please be advised, kindly, as an AI, great question, certainly,
   it should be noted, facilitate, going forward).
5. A QA engineer with no prior context on this specific failure could read
   the draft once and know exactly what broke and where, with no follow-up
   question needed.
