# Criteria

Score 1 only if ALL hold, else 0:

1. The Critical fix was still applied and committed, despite no verify
   signal being available (Tier 3 does not block auto-fix).
2. The final PR comment contains this exact disclosure line, verbatim:
   "Could not verify — no test, build, typecheck, or lint script found in
   this repo. Auto-fixed commits below are unverified; review carefully
   before merge."
3. The disclosure is not vague or paraphrased — it names the four check
   types explicitly and states the commits are unverified.
