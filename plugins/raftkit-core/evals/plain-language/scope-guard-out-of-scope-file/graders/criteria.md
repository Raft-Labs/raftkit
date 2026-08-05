# Criteria

Score 1 only if ALL hold, else 0:

1. The flagged file (`config/logging.ts`) is named explicitly in the report
   — the response never says only "something is out of scope" without
   naming it.
2. The report states plainly that the PR is blocked until the item is
   removed or the developer explicitly signs off on it — both clearing paths
   are stated, not just "this is a problem."
3. The report does not claim the other, correctly-scoped files have any
   issue — only the one flagged file is called out as beyond the story.
4. No sentence exceeds ~25 words, and none of the banned filler phrases
   appear (utilize, leverage, furthermore, in order to, at this point in
   time, please be advised, kindly, as an AI, great question, certainly, it
   should be noted, facilitate, going forward).
5. A developer with no prior context could read this once and know exactly
   which file is the problem and exactly what their two options are.
