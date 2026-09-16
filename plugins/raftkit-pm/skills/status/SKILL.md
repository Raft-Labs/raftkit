---
name: status
description: Draft a client-facing status update from one project's Asana board — "draft the weekly client update", "status update for <project>", "what do we tell the client this week". Reads the board live, drafts the house-style update where every line traces to a task and the whole thing ends with exactly one ask, and never sends. Client updates only.
user-invocable: true
---

# status

One project's board → a client-ready update the PM sends. `raftkit-core:rules` apply. This skill writes nothing and never sends: the draft is handed back and the PM sends it from their own channel. It has no stop.

## Inputs

One project (link, GID or name; none → ask). A date range: since the last update if known, else 7 days; capped at 4 weeks, the clamp stated; an invalid range is asked once.

## Run

1. **Read the board once**: sections, tasks and status-carrying comments for the range. Bad link → say the identifier is wrong; no access → say the connector cannot reach the project.
2. **Classify by real state**, every item tied to its task: Shipped (completed in range) · In progress (touched, incomplete) · Blocked (blocker, owner, next step, or "unclear on the board", never invented) · Decisions needed (waiting on the client).
3. **Draft** in the house voice: sharp, direct, semi-formal, no filler; one line per item in client terms; omit an empty section. Every line maps to a board item; a claim without one does not go in.
4. **Close with exactly one ask.** Several open decisions → rank by what blocks the most, lead with the top one, and end on that one, phrased so the client can answer in a sentence. Never zero asks, never a list of asks.
5. **Hand back**, ending with the same line every time:

```output
Review, edit, send — I don't send.
```

## Thin and empty weeks

A thin week is reported as thin. No activity → open with `Quiet period — no shipped items this week`, then the standing ask (the most recent open decision). No open decision either → ask the PM what the client owes before drafting. Never pad.

Anything touching budget, contract or a client commitment is surfaced for the PM, never committed in the draft.
