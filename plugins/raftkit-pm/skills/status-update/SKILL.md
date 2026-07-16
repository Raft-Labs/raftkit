---
name: status-update
description: This skill should be used when a RaftLabs PM wants to compile a client-facing status update from a project's Asana board — e.g. "draft the weekly client update", "status update for <project>", "write the client update from the board", "what do we tell the client this week". Reads one project's board live (shipped / in progress / blocked / decisions needed), drafts a sharp, house-style update where every line traces to a task and the whole thing ends with exactly one ask, and never sends — the PM reviews, edits, and sends. Client updates only, not internal standups.
user-invocable: true
---

# status-update

Turn one project's board state into a client-ready update the PM can send as-is:
what shipped, what's in progress, what's blocked, and what decision the client
owes us — ending with exactly one clear ask. The house rule this enforces: every
client update ends with a decision or an action; open-ended updates are banned
(PRD §5.2). Compiling it from real board state keeps that discipline cheap and
keeps every line honest — traceable to a task, never invented.

## The one rule that governs everything

**This skill never sends.** It produces a draft in chat and stops. There is no
send step, no Gmail/Slack write, no scheduled delivery — sending is the PM's act,
in the PM's own channel. Every run ends by handing the draft back with:

> review, edit, send — I don't send

If asked to send, decline and restate that line.

## Inputs — gather before drafting

1. **One project** — a board link, GID, or name the PM points at. One project per
   run; never blend two. If none is given → ask which project.
2. **Date range** — default: since last update if known, else 7 days. Capped at
   **4 weeks**; a longer request is clamped and the clamp is stated. An invalid
   range (end before start, unparseable) → ask once, then stop.

Nothing is cached: the board is read **live** by GID every run. raftkit-core is
required for `house-rules`; if it is missing, stop with the exact
`workflow-constants` message rather than proceeding.

## Run flow

1. **Read the board live.** Fetch the project's sections, tasks, and the comments
   that carry status, through the Asana connector, for the resolved range. If the
   project can't be read, handle it per Errors below — never guess its contents.
2. **Classify by real state**, every item tied to its task:
   - **Shipped** — completed within the range.
   - **In progress** — active/incomplete, touched in the range.
   - **Blocked** — carries blocker + owner + next step (see the format reference).
   - **Decisions needed** — items waiting on a client call.
3. **Draft in the house voice** per `references/update-format.md`: sharp, direct,
   semi-formal, no filler. Every line traces to a task or a task comment — if a
   fact isn't on the board, it does not go in the update.
4. **Close with exactly one ask.** If several decisions are open, rank them and
   lead with the top one; the update ends on that single ask.
5. **Hand back the draft** in chat, ending with the never-send line. Stop there.

## Edge cases — WEESLD

- **Waiting** — on a large board, say the scan is running before the draft lands.
- **Empty** — no activity in range: state it plainly with
  `Quiet period — no shipped items this week` and still close with the standing
  ask. Never pad an empty week into a full-looking one.
- **Error (most important)** — an unreadable project names the **exact** access
  issue, and the two causes are distinguished because the fix differs:
  - bad link / invalid GID → say the identifier is bad and to check the URL / GID;
  - no access → say the connector has no access to this project and to grant it.
  An invalid date range → ask once.
- **Success** — the draft is in chat, ending with the never-send handoff line (see
  The one rule above).
- **Limits** — one project per run; range capped at 4 weeks.
- **Default values** — range = since last update if known, else 7 days.

## Guardrails

- **Board facts only.** No invented progress, no rounded-up status, no
  placeholder. A thin week is reported as a thin week. If a blocked item is
  missing its owner or next step on the board, flag the gap in the draft — do not
  fabricate one.
- **One ask, always.** The update ends with exactly one decision or action for the
  client. Ranked if several compete; never zero, never a vague "let us know".
- **Escalate to founders** (`raftkit-core/house-rules`) on budget, contracts,
  relationship risk, or anything that reads as a client commitment — surface it in
  the draft for the PM; the skill never commits on RaftLabs' behalf.
- **Client updates only** in v1 — not internal standups.

## Reference file

- **`references/update-format.md`** — the draft's section structure, the
  blocked-line shape (blocker + owner + next step), the one-ask ranking rule, the
  traceability rule, and how empty / thin weeks are handled.
