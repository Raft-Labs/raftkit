---
name: write-protocol
description: This skill should be used before any RaftKit skill writes to Asana or produces client-facing output — creating or updating a task, adding a comment, posting a status update, ticking a subtask, or sending anything a client will read. It defines the draft-then-approve gate and the Asana HTML formatting rules that every such write must follow. Consult it whenever a write, push, send, comment, or status update is about to happen, even if not explicitly requested.
user-invocable: false
---

# RaftKit Write Protocol

Every write to Asana or to a client-facing surface passes through one gate: **draft → approve → push**. RaftKit skills draft; humans approve; only then does anything leave the chat. This holds for task creation and edits, comments, status updates, subtask completion, and any message a client will see — no exceptions.

The reason is trust. An automated write that turns out wrong is visible to a client or teammate before anyone can catch it. Keeping a human in the loop on every outward write means mistakes get caught while they are still drafts.

## The gate

1. **Draft in chat.** Show the exact content to be written and name the exact target — which task, comment thread, project, or surface it lands on.
2. **Wait for explicit human approval.** Silence is not approval. A related instruction from earlier is not approval for this specific write. Wait for a clear go on the drafted content.
3. **Push only after approval** — and push exactly what was approved, applying the Asana HTML rules below.

No skill ever auto-sends, auto-merges, auto-files, or auto-completes. If a workflow feels like it should "just do it," that is the case the gate exists for.

## Asana HTML rules (apply on push)

Asana's rich-text (`html_notes` / `html_text`) is strict. A body that violates these rules is rejected or renders wrong. When pushing formatted content to Asana, apply all of the following:

- **Single body root.** Wrap the whole body in one root node (`<body>…</body>`); do not emit multiple top-level nodes.
- **No `<p>` tags.** Separate paragraphs with line breaks, not paragraph elements.
- **Attributes only on links.** The only element allowed to carry attributes is `<a>` (its `href`). Strip attributes from every other tag.
- **Escape entities.** Escape `&`, `<`, and `>` in text content so they are not parsed as markup.

When in doubt, prefer plain text with line breaks over rich formatting — it always renders and never gets rejected.
