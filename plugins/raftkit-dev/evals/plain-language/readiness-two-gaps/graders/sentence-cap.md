---
type: regex
pattern: '(?:(?=\S*[\p{L}\p{N}])\S*[^\s.!?][ \t]+(?:[^\s\p{L}\p{N}]+[ \t]+)*){25}(?=\S*[\p{L}\p{N}])\S'
flags: u
match: not_contains
---

No sentence runs past 25 words: no line holds 26 words before a sentence ends. Symbol-only tokens (— · |) are not counted and a line break ends the run, so this is a little more lenient than scripts/check-plain-language.mjs.
