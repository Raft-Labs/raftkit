---
name: meeting
description: Turn one client call into cited decisions, a Project Profile delta and an Asana task batch — "extract the decisions from this call", "turn this call into action items and tasks", "what did we decide and who owns what". Every item carries a transcript citation; out-of-scope asks are flagged SCOPE CHANGE; one stop covers everything. Scheduling — raftkit-pm:routine.
user-invocable: true
---

# meeting

One transcript → decisions, scope changes and action items, each cited; then a Profile delta and a task batch. `raftkit-core:rules` apply. Fathom already writes the recap; this skill writes none.

**No citation, no claim.** An item that cannot be tied to a transcript moment is dropped or raised as a question, never asserted.

## Inputs

One meeting: a Fathom link or name, or an uploaded transcript. The Asana project the call belongs to, named by the PM and never inferred from what the transcript mentions. Its Project Profile is found by convention; no profile means there is nothing to update:

```output
Can't extract — no Project Profile for this project. Run raftkit-pm:profile first, then re-run.
```

## Run

1. **Read at once**: the transcript (pass the recording URL so citations become timestamped deep links; an upload cites its inline timestamps), the Profile, and the workspace members for assignee lookup. A long transcript is read in chunks and merged; never truncated.
2. **Extract** per `references/extraction.md`: decisions, scope changes (flagged `SCOPE CHANGE`, routed to the PM or to founders when commercial), action items. Nothing found → say so and create nothing.
3. **Draft, in one message**:
   - the three cited lists;
   - the Profile delta: changed / new / now-confirmed facts, cited `<meeting> @ <timestamp>`, dated the meeting date, ⚠️ by default (only an unambiguous on-call decision earns ✅), conflicts with existing facts shown with both citations, the subtasks it overwrites named, and the delta comment;
   - the task batch: one task per action item with title, citation, suggested assignee (the owner named on the call; unclear → a question in the draft; unresolved → unassigned, never guessed), recording and related-task links in the description, a due date only when the call set one.
4. **Stop once.** The PM may approve parts: "delta yes, tasks except #3."

```output
Call "Riverside weekly, 12 Aug": 4 decisions, 1 SCOPE CHANGE (routing: founders), 6 action items.
Profile delta: 3 changed, 2 new, 1 conflict. Tasks: 6 proposed, 1 owner unclear (question above).
**STOP** — approve all or name the parts, edit to change, or decline.
```

5. **On go**: write the approved parts, read back once, report each created task with its link and anything left unassigned.

Nothing is sent to Slack or email. A decision that touches budget, contract or a client commitment is surfaced for founders, never treated as settled.
