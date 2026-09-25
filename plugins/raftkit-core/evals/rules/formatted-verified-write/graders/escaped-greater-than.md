---
type: regex
pattern: '(?<!`)<body>(?!`)(?:(?!</body>)[\s\S])*?&gt;\s*10'
match: contains
---

The `>` in "> 10" is escaped in the payload.
