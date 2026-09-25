---
type: regex
pattern: '(?<!`)<body>(?!`)(?:(?!</body>)[\s\S])*?&amp;'
match: contains
---

The `&` in the config note is escaped in the payload.
