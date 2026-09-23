---
type: regex
pattern: 'RaftKit setup v[0-9]'
match: not_contains
---

Nothing is applied before the go, so the run never prints setup's success line.
