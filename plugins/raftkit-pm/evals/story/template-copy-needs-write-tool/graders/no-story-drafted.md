---
type: regex
pattern: '^\s*(?:\*\*)?(?:STORY:|\[AC\]\s)|^\s*(?:[-*]|\d+[.)])\s+(?:\*\*)?\[AC\]\s'
flags: m
match: not_contains
---

No story header and no drafted `[AC]` line: nothing is shaped from a remembered template.
