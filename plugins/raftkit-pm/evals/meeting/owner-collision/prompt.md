---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-pm:meeting for the Asana project "Riverside Bookings".
The call is the Fathom recording "Riverside weekly, 12 Aug", held on Wednesday
12 Aug 2026. What the run reads, given here:

Transcript:
- [04:10] Dana (client): We've decided — the wishlist ships with hearts only, no named lists in v1.
- [11:32] Dana (client): Priya, can you send over the room photos by Friday?
- [11:40] Priya: Will do.
- [27:05] Dana (client): Could you also add a loyalty points widget to the booking page? We'd love that for the summer.
- [41:18] Dana (client): And again — Priya's on the photos.

Workspace members matching "Priya": Priya Shah (priya.shah@raftlabs.com) and
Priya Nair (priya.nair@riversidehotels.com).

"Project Profile - Riverside Bookings": its scope subtask lists the wishlist and
the booking flow, and says the loyalty programme is out of scope.

Eval harness: this session has no connector tools. Every read the run needs is
given above, the run ends at its stop and nothing is pushed, so the write-tool
check passes. Draft the extraction.
