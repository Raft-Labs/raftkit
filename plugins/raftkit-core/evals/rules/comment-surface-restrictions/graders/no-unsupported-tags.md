---
type: regex
pattern: '(?<!`)<body>(?!`)(?:(?!</body>)[\s\S])*?<(?:h[1-6]|table|thead|tbody|tr|td|th|hr|img|p|br)\b'
flags: i
match: not_contains
---

Inside the payload: no heading, table, rule, image, paragraph or line-break tag. Comments reject or mangle them.
