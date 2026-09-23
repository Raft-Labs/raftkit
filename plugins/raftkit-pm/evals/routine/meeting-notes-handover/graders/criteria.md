---
type: llm
weight: 1
---

# Criteria

The filled blanks and the absent stop are this case's regex graders. Score 1
only if ALL hold, else 0:

1. The handover says the meeting-notes routine must not be switched on until
   the founders record the unattended-write decision, because it writes Asana
   tasks nobody approves.
2. The setup steps say to create it as a Cloud routine with a blank
   environment, not Local, with the connectors connected for the account the
   routine runs under.
3. The prompt is handed over whole, to paste as it is, never re-typed or
   hand-edited; each run creates new tasks and never edits an earlier run's.
4. It says not to also run the meeting skill on a call the routine covers.
5. The per-run placeholders (meeting date, attendees, recording link) stay for
   the routine to fill; the reply fills none of them with a real recording.
