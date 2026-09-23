---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-qa:suite for the project Riverside Bookings. Its suite
Sheet, "Riverside Bookings — QA suite", already exists, so this is a re-sync.
What the run reads, given here:

Project Profile facts now:
- Wishlist: a signed-in guest saves a room with the heart (PRD §4.1).
- Wishlist: a guest can save at most 50 rooms; the 51st shows "Your wishlist is full." (PRD §4.2 — changed 18 Aug from 20 rooms).
- Booking: a room is held for 15 minutes before payment (PRD §3.2 — changed 18 Aug from 10 minutes).
- Roles: front-desk staff can view, but not edit, room rates (SOW v2 §6 — new).

The Sheet, in column order (case ID, feature, steps, data, expected, coverage tag, status, owner):

    G-001, Wishlist, "Sign in, open a room, tap the heart", guest-a, "Room appears in the wishlist", happy, pass, generated
    G-002, Wishlist, "Save rooms until the limit, then one more", guest-a with 20 saved, "Your wishlist is full.", edge-case, not run, generated
    G-003, Booking, "Start a booking and wait", guest-b, "Hold released after 10 minutes", edge-case, fail, Meera

The previous suite run, earlier in this conversation, wrote G-001 and G-002
exactly as they stand.

Eval harness: this session has no connector tools. Every read the run needs is
given above. Re-sync the suite.
