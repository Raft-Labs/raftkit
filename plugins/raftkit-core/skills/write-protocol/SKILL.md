---
name: write-protocol
description: This skill should be used before any RaftKit skill writes to an outward destination — an Asana task or comment, a Google Drive doc (created or updated via connector or a synced folder), a local or synced file, or anything a client will read. It defines the draft-then-approve gate every such write must follow and the Asana HTML formatting rules for Asana destinations. Consult it whenever a write, push, send, comment, file creation or update, or status update is about to happen, even if not explicitly requested.
user-invocable: false
---

# RaftKit Write Protocol

Every outward write — Asana, a Drive doc, a local or synced file, or any client-facing surface — passes through one gate: **draft → approve → push**. RaftKit skills draft; humans approve; only then does anything leave the chat. This holds for task creation and edits, comments, status updates, subtask completion, file creation and updates, and any message a client will see — no exceptions beyond the two named below.

The reason is trust. An automated write that turns out wrong is visible to a client or teammate before anyone can catch it. Keeping a human in the loop on every outward write means mistakes get caught while they are still drafts.

## The gate

1. **Draft in chat.** Show the exact content to be written and name the exact target — which task, comment thread, project, document, file path, or surface it lands on. When updating an existing doc or file, show the change against its current content, not just the new text.
2. **Wait for explicit human approval.** Silence is not approval. A related instruction from earlier is not approval for this specific write. Wait for a clear go on the drafted content.
3. **Push only after approval** — and push exactly what was approved, applying the Asana HTML rules below when the destination is Asana; any other destination gets the approved content pushed as-is.

No skill ever auto-sends, auto-merges, auto-files, or auto-completes. If a workflow feels like it should "just do it," that is the case the gate exists for.

## The one documented exception

Exactly one mechanism is exempt from the per-write draft/approve round, and it
is enumerated here in full. It is not client-facing, and it may not be extended
by analogy.

Blocker telemetry was previously a second exception, auto-filing issues on
RaftLabs' tooling repo. It writes nowhere outward now — blockers are reported
to the admin dashboard as telemetry and triaged there — so the rule above holds
for it with no exception at all. It still captures prompts, and a developer
switches the whole of telemetry off with `RAFTKIT_TELEMETRY=off` (or
`DO_NOT_TRACK=1`) in the environment. See Telemetry and blocker capture in
[house-rules](../house-rules/SKILL.md).

### `pr-auto-review` Critical-fix commits (CI layer)

`raftkit-dev`'s `pr-auto-review` skill installs a CI workflow that commits
directly to a PR branch without a per-write draft/approve round in chat — a
deliberate, narrow exception to "no skill ever auto-sends, auto-merges,
auto-files, or auto-completes" above. The exception is scoped exactly this
far and no further:

- **What it may do without per-write approval.** Commit a fix for a single
  **Critical**-severity finding from `pr-review-toolkit:review-pr` — one
  commit per fix, conventional-commit form, the finding's file:line and a
  `pr-auto-review-commit: true` trailer carried in every commit message so
  the write is fully attributed to this mechanism, never anonymous.
- **What stays gated exactly as before.** Everything else this skill's
  workflow touches is unchanged by this exception: it never merges the PR
  (merge is always human), never touches Important or Suggestion findings
  (reported only, in the PR comment below), never pushes to a protected
  branch directly, never edits `.github/workflows/**` (including its own
  workflow file), and posts no Asana write of any kind.
- **The safety net that makes the exception acceptable.** Every fix is
  applied, then reverified against the repo's available check (test suite
  when one exists; a named weaker signal, disclosed as such, when it does
  not; and — the one deliberate exception-within-the-exception — still
  committed with a permanent "unverified" disclosure when no check exists at
  all). A fix that turns any available check red is auto-reverted
  immediately and reported by name in the same PR comment as "could not
  auto-fix safely" — never left half-applied, never silently dropped.
- **Why a single PR comment, not chat.** There is no chat session to draft
  into — the workflow runs headless in CI. The PR comment (edited in place
  on every re-run via a hidden marker, never duplicated) **is** the
  draft-then-approve gate's replacement here: every commit it made is named
  with a link, every finding it did not touch is listed, and the human merge
  decision that follows is exactly as informed as a chat-drafted write would
  have made it — the approval gate simply moves from "approve before push"
  (impossible headless) to "the commit is fully visible and revertible
  before the human's merge decision" (the only gate a CI-native workflow can
  offer).

Nothing beyond these two is exempt. If you are reasoning about a client-facing
write, the gate above applies without exception, and no skill may extend this
entry by analogy. A future skill that wants to auto-write anything else needs
its own named, reviewed amendment to this list — the entry above authorizes
`pr-auto-review`'s Critical-fix commits, and nothing more.

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

## Guardrails

- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.
