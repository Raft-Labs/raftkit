Gate 1 approved a Design Approach decision, D2, phase 1: "the handler validates
input and delegates to a domain function — it never queries the database
directly." The story's phase-1 diff is done, but the handler still contains
an inline database query; no domain function was ever created.

Run scope-guard against this diff.
