---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-pm:routine to set up the meeting-notes routine. The PM
answered the setup questions in one message: the Asana project is Riverside
Bookings, the recording is the recurring "Riverside weekly" call, Sana Iqbal
chases items owned by people outside the workspace, and the board has no title
convention of its own.

What the run reads, given here:

- Asana project name, read back: "Riverside Bookings — Delivery".
- Fathom recordings: "Riverside weekly, 12 Aug" (https://fathom.video/calls/448812) and "Riverside weekly, 5 Aug" (https://fathom.video/calls/447190).
- Workspace member for the fallback: Sana Iqbal (sana@raftlabs.com), one match.

Eval harness: this session has no connector tools; every read the run needs is
given above. Hand over the routine.
