---
type: regex
pattern: '(?<!`)<body>(?!`)(?:(?!</body>)[\s\S])*?(?:#{2,}|\||^\s*-{3,}\s*$|^\s*[-*] )'
flags: m
match: not_contains
---

The payload carries no raw markdown: no `##`, no table pipes, no `---` divider, no `-` bullets.
