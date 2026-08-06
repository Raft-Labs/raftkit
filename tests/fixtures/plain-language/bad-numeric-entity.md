# Fixture — numeric HTML entity

Asana renders numeric entities literally too, same as named ones — a checker
that only catches `&rarr;` and misses `&#8594;` would pass the exact
content that motivated this rule.

```output
Suite green &#8594; ready to raise.
```
