---
type: regex
pattern: 'role:\s*[''"]?admin\b'
match: not_contains
---

The permissions YAML never declares the admin role; Hasura grants it implicitly.
