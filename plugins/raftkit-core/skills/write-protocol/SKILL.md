---
name: write-protocol
description: This skill should be used before any RaftKit skill writes to an outward destination — an Asana task or comment, a Google Drive doc (created or updated via connector or a synced folder), a local or synced file, or anything a client will read. It defines the draft-then-approve gate every such write must follow and the Asana HTML formatting rules for Asana destinations. Consult it whenever a write, push, send, comment, file creation or update, or status update is about to happen, even if not explicitly requested.
user-invocable: false
---

# RaftKit Write Protocol

Every outward write — Asana, a Drive doc, a local or synced file, or any client-facing surface — passes through one gate: **draft → approve → push**. RaftKit skills draft; humans approve; only then does anything leave the chat. This holds for task creation and edits, comments, status updates, subtask completion, file creation and updates, and any message a client will see — no exceptions.

The reason is trust. An automated write that turns out wrong is visible to a client or teammate before anyone can catch it. Keeping a human in the loop on every outward write means mistakes get caught while they are still drafts.

## The gate

1. **Draft in chat.** Show the exact content to be written and name the exact target — which task, comment thread, project, document, file path, or surface it lands on. When updating an existing doc or file, show the change against its current content, not just the new text.
2. **Wait for explicit human approval.** Silence is not approval. A related instruction from earlier is not approval for this specific write. Wait for a clear go on the drafted content.
3. **Push only after approval** — and push exactly what was approved, applying the Asana HTML rules below when the destination is Asana; any other destination gets the approved content pushed as-is.

No skill ever auto-sends, auto-merges, auto-files, or auto-completes. If a workflow feels like it should "just do it," that is the case the gate exists for.

## Asana HTML rules (apply on push)

Rendering is delegated to the `asana-formatting` skill — it owns the per-surface
tag matrix, the markdown-to-HTML conversion, object mentions, and the read-back
verification. This gate always precedes that rendering: draft → approve → push,
then format and verify per `asana-formatting`.

These four rules are the floor `asana-formatting` refines; a body that violates
them is rejected or renders wrong:

- **Single body root.** Wrap the whole body in one root node (`<body>…</body>`); do not emit multiple top-level nodes.
- **No `<p>` tags.** Separate paragraphs with line breaks, not paragraph elements.
- **Attributes only on links.** The only element allowed to carry attributes is `<a>` (its `href`). Strip attributes from every other tag.
- **Escape entities.** Escape `&`, `<`, and `>` in text content so they are not parsed as markup.

Read before write: the default is comments, never description overwrites; a
description is overwritten only on an explicit human instruction to do so.
After the push, read the result back and verify the render (`asana-formatting`
→ `references/verification.md`); a mismatch is reported, never silently
rewritten. When in doubt, prefer plain text with line breaks over rich
formatting — it always renders and never gets rejected.
