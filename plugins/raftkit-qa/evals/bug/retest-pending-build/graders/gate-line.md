---
type: regex
pattern: 'Can[’'']t retest — no build to test against\. Fill [“"]Fixed in build ___[”"] or name it in the hand-back, then hand it back\.'
match: contains
---

`Fixed in build: pending — …` counts as empty, so the retest stops on the skill's first gate line.
