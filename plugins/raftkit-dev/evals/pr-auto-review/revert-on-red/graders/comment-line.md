---
type: regex
pattern: 'Could not\s+auto-fix safely: src/parser\.js:20 — attempted fix broke [^\n]*(?:parser\.test|handles empty input)[^\n]*Reverted; left for manual review\.'
match: contains
---

The PR comment names the finding and the specific failing check in the fix-loop prompt's exact line.
