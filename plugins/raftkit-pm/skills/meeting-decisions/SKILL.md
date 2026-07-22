---
name: meeting-decisions
description: This skill should be used when a RaftLabs PM wants to turn a client call into cited decisions, a Project Profile update, and Asana tasks — e.g. "extract the decisions from this Fathom call", "run meeting-decisions on <recording>", "turn this call into action items and tasks", "what did we decide and who owns what on that call", or an uploaded transcript file to process. It reads one transcript (Fathom recording or uploaded file), extracts decisions / scope changes / action items each cited to a transcript timestamp, flags out-of-scope requests as SCOPE CHANGE, and proposes a Project Profile delta and an Asana task batch as two separately PM-approved gates. Requires an existing Project Profile (routes to project-onboarding if missing); writes and creates nothing without approval.
user-invocable: true
---

# meeting-decisions

Turn one client call into three durable outputs: **cited decisions**, an **updated
source of truth**, and **assigned tasks** — so nothing agreed in a meeting evaporates.
Ashit's review flagged this workflow explicitly; the flowhoney project lost time to
decisions that lived only in call recordings (PRD §5.2). Meetings are a primary
source, so they must feed the Project Profile like any other.

This skill orchestrates the Fathom connector (read the transcript) and the Asana
connector (create the tasks); it authors no summary of its own — Fathom already does
that (see Guardrails).

## The rules that govern everything

- **No citation, no claim.** Every extracted item carries a transcript citation in
  the form defined in `references/extraction-and-citations.md`. An item that cannot
  be cited to the transcript is not asserted — it is dropped or raised as a question,
  never stated as fact.
- **Two separate approval gates.** The Project Profile delta and the task batch are
  approved independently: approving one never implies the other, and neither is
  written or created without its own explicit PM approval (draft → approve → push,
  `raftkit-core/write-protocol`). Silence is not approval.
- **Scope is a hard line.** A request beyond current scope is flagged, labelled, and
  routed — never silently absorbed into the plan. The fixed flag wording and the
  routing rule live in `references/extraction-and-citations.md`.
- **Ambiguous assignee = ask, never guess.** An unclear owner triggers exactly one
  focused question; an unresolved owner defaults to unassigned, never to a guessed
  name.

## Inputs — gather before extracting

1. **One meeting transcript** — a Fathom recording (a link or a meeting name the PM
   points at) **or an uploaded transcript file**. One meeting per run; never blend
   two. A name is resolved by listing/searching Fathom meetings; a link resolves
   directly; an upload is used as-is and cited as "uploaded transcript, as-of
   \<date\>". If none is given → ask which meeting.
   Resolution failures are handled under Edge cases (Error).
2. **The Project Profile** — its home is **an open decision on the raftkit board**,
   so the PM points at where the profile lives (the same parameterized home
   `project-onboarding` writes to); never hardcode a path or connector. **No profile
   exists → route to `project-onboarding` first** (see Edge cases · Error) — this
   skill updates a profile, it does not create one.

`raftkit-core` is required for `workflow-constants`, `house-rules`, and
`write-protocol`; if it is missing, stop with the exact **missing-core** message from
`raftkit-core/workflow-constants` rather than proceeding.

## Run flow

1. **Resolve the recording.** Turn the link or meeting name into one Fathom
   recording — or take the uploaded transcript file as the meeting. If it cannot be
   resolved, handle it per Edge cases (Error) — never
   guess which meeting was meant.
2. **Read the transcript.** Fetch it through the Fathom connector,
   passing the recording URL so citations become timestamped deep links; an uploaded
   transcript is read directly and cites its own inline timestamps
   (`references/extraction-and-citations.md`). Long
   transcripts are processed in chunks with a progress note per chunk
   (see `references/extraction-and-citations.md`); never truncate a transcript
   silently.
3. **Extract the three categories, each cited.** Pull **decisions**, **scope
   changes**, and **action items**, each with its transcript citation, per
   `references/extraction-and-citations.md`. Flag every out-of-scope request with the
   fixed **SCOPE CHANGE** flag against its source. No decisions found → Edge cases
   (Empty).
4. **Present the extraction** in chat for review — the three cited lists, with scope
   changes visibly flagged. This is the shared basis for both gates that follow.
5. **Gate A — Project Profile delta.** Draft the delta the decisions imply (changed /
   new / now-confirmed facts, e.g. ⚠️ → ✅ with the call as citation), name the exact
   profile home it lands on, and write it **only after PM approval**, via
   `write-protocol`. See `references/gates-and-writes.md`.
6. **Gate B — Asana task batch.** Propose the action items as a task batch with a
   suggested assignee each; ask one focused question for any unclear assignee. Create
   the tasks **only after the PM confirms the batch**, respecting the Asana free tier,
   and report each created task with its link. See `references/gates-and-writes.md`.
7. **Report.** Summarize what was extracted, what the profile delta changed (if
   approved), and which tasks were created with links (if confirmed) — naming any gate
   the PM declined so nothing looks done that was not.

## Edge cases — WEESLD

- **Waiting** — a long transcript announces chunked processing and reports progress
  per chunk, so a slow run stays legible.
- **Empty** — no decisions found: say exactly that, suggest checking the Fathom
  summary, and **create nothing** — no profile delta, no tasks.
- **Error (most important)** — name the exact failure and its fix, and distinguish
  the two recording causes because the fix differs:
  - **recording not found** (bad link / wrong meeting name) → say the identifier is
    bad and to check the link or name;
  - **no access** (Fathom permission) → say the connector cannot reach this recording
    and to grant access.
  - **profile missing** → do not invent one; route to `project-onboarding` to build
    the profile first, then re-run.
- **Success** — decisions listed and cited, the approved profile delta applied, and
  the confirmed tasks created with links.
- **Limits** — **one meeting per run.** A second meeting is a separate run.
- **Default values** — an unresolved task assignee defaults to **unassigned**
  (plus the focused question), never to a guessed owner.

## Guardrails

- **Read-only on the transcript.** The transcript and the meeting are read, never
  modified. The only writes are the approved profile delta and the confirmed tasks.
- **No meeting summaries for their own sake** — Fathom already produces those; this
  skill extracts decisions / scope changes / actions, not a recap.
- **Asana free tier only** on anything created — no structured Asana feature the free
  tier lacks. The canonical exclusion list is `raftkit-core/house-rules`' free-tier
  rule; `references/gates-and-writes.md` applies it to the task batch.
- **No Slack/email follow-ups** — out of scope (M6 backlog); this skill neither sends
  nor drafts them.
- **Escalate to founders** (`raftkit-core/house-rules`) when a scope change or
  decision touches budget, contracts, relationship risk, or a client commitment — the
  skill surfaces it; it never commits on RaftLabs' behalf.

## Reference files

- **`references/extraction-and-citations.md`** — the three extraction categories, the
  single citation form (`<meeting> @ <timestamp>` deep link) and the no-citation-no-
  claim rule, the fixed always-caps **SCOPE CHANGE** flag wording and its routing, and
  chunked processing of long transcripts.
- **`references/gates-and-writes.md`** — the two independent approval gates: the
  Project Profile delta (changed / new / now-confirmed, aligned with
  `project-onboarding`'s profile format) and the task batch (assignee resolution,
  the Asana free-tier task shape, and per-task reporting).


## Asana rendering

All Asana output is rendered and verified through core `asana-formatting` (per-surface tag matrix, markdown→HTML conversion, mentions, read-back verification), behind the `write-protocol` draft → approve → push gate.
