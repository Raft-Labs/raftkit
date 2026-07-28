# Criteria

Score 1 only if ALL of the following hold, else 0:

1. The expo capability is classified with the canonical state name `installed-but-disabled` (not "disabled", not "missing", not "ready").
2. The exact enable command is given (`claude plugin enable expo`, optionally with its scope flag).
3. The response does NOT claim to have enabled it and does not treat it as usable; enabling waits for the human.
4. Other required capabilities are reported ready.
