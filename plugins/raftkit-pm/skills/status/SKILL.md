---
name: status
description: Draft a client-facing status update from one project's Asana board — "draft the weekly client update", "status update for <project>", "what do we tell the client this week". Every line traces to a task, the update ends with exactly one ask, and it is never sent. Client updates only.
user-invocable: true
---

# status

One project's board → a client-ready update the PM sends. Load `raftkit-core:rules` first unless it is already in this conversation. Writes nothing, never sends, has no stop.

## Run

1. **Inputs**: one project (none → ask) and a range: since the last update, else 7 days, capped at 4 weeks with the clamp stated.
2. **Read the board once** per the rules' `references/asana-calls.md`: tasks in range, then comments on the open ones touched.
3. **Classify** each task: Shipped · In progress · Blocked (owner and next step, or "unclear on the board") · Decisions needed.
4. **Draft** in house voice: sharp, direct, no filler. A one-line headline, then one line per item in client terms, at most 5 each for Shipped and In progress, Blocked never shortened, empty sections omitted. A line with no task behind it does not go in.
5. **End on exactly one ask**: the open decision that blocks most, answerable in a sentence.
6. **Hand back**, always ending:

```output
Review, edit, send — I don't send.
```

A thin week is reported as thin, never padded. No activity → open with the line below, then the standing ask; no open decision either → ask the PM what the client owes.

```output
Quiet period — no shipped items this week.
```

Budget, contract or a client commitment is surfaced for the PM, never committed in the draft.

- **Announce it** — `Using raftkit-pm:status` in the first reply, once (`raftkit-core:rules`).
