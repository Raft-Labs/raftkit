# Criteria

Score 1 only if ALL hold, else 0:

1. The response uses the current owned wording — "Missing: <capability>.
   Install it with: <exact command>" followed by "Needs your approval first
   — nothing installs until you say go." — not the old three-clause form
   ("Required capability unavailable: ... Proposed install command (human
   approval required): ... Stopping — no fallback.").
2. The exact install command is named, not described vaguely ("some install
   command").
3. The response makes clear nothing installs until the developer approves —
   it does not install anything itself and does not proceed with the story
   using a workaround.
4. No sentence exceeds ~25 words, and none of the banned filler phrases
   appear (utilize, leverage, furthermore, in order to, at this point in
   time, please be advised, kindly, as an AI, great question, certainly, it
   should be noted, facilitate, going forward).
5. A developer with no prior context could read this once and know exactly
   what is missing, what command installs it, and that they must approve
   first.
6. The response wraps its output in the output fence (` ```output `) per
   plain-language.md's convention, and glosses any house term it uses inside
   that block — e.g. "capability preflight" — in one line on first use there.
   The fenced text also includes the literal line "Needs your approval first
   — nothing installs until you say go."
