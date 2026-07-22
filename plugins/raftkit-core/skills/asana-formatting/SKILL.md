---
name: asana-formatting
description: This skill defines how RaftKit renders content for Asana so it displays correctly and verifiably. It is consulted by write-protocol and by every RaftKit skill that writes to Asana — task descriptions, comments, project briefs, status posts, subtask edits. It provides the per-surface tag matrix, the markdown-intent to Asana-HTML conversion rules, object-reference/mention syntax, the read-before-write and comments-by-default rules, and the read-back verification contract. Not user-invocable.
user-invocable: false
---

# Asana formatting

Asana renders **HTML only** — markdown is never rendered. Every RaftKit write to
Asana is hand-crafted from a restricted tag set, then verified by reading the
result back. This skill is the single source of those rules; `write-protocol`
delegates its four formatting rules here, and every Asana-writing skill routes
its rendering through this contract.

This skill formats and verifies; it never sends. The **draft → approve → push**
gate lives in `write-protocol` and always precedes any push.

## Read before write

Call the connector's get-task (with comments) before any edit. The default is
**comments, never description overwrites** — completion updates and status go in
as comments. A task description is overwritten **only** when the human
explicitly says to update the description. Never overwrite a description on an
inferred instruction.

## Conversion, per surface, and mentions

- `references/tag-matrix.md` — which tags each surface (description, comment,
  project brief) accepts, and what silently degrades.
- `references/conversion.md` — markdown intent → the Asana HTML subset.
- `references/mentions.md` — object references and @-mentions, with the
  no-access fallback.
- `references/verification.md` — the read-back check and failure handling.

## The four write-protocol rules (the floor)

Every push obeys these — write-protocol delegates them here and they are the
minimum, refined by the references above:

- **Single body root** — wrap the whole body in one `<body>…</body>`.
- **No `<p>` tags** — separate blocks with block-level elements, never `<p>`.
- **Attributes only on links** — the only element that carries attributes is
  `<a>` (its `href` and `data-asana-*`).
- **Escape entities** — escape `&`, `<`, `>` in text content.

## Boundaries

Formats and verifies only. Never sends without the write-protocol gate; never
overwrites an approved draft's content silently; when in doubt, prefer plain
text with line breaks over rich formatting — it always renders.
