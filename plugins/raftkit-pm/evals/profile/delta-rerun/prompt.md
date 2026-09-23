---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-pm:profile for the Asana project "Riverside Bookings".
The PM named one new source: "SOW v2" (Drive, as-of 18 Aug 2026). What the run
reads, given here:

- Project: Riverside Bookings (1200000000000042), one match.
- The existing task "Project Profile - Riverside Bookings" and its four subtasks:
  - Business rules and limits: "Guests pay by card only." ⚠️ Partial (kick-off call @ 12:40, as-of 1 Jul).
  - Roles and permissions: "Only hotel admins can edit room rates." ✅ Confirmed (PRD §2.1, as-of 2 Jul).
  - Integrations: "Payments run through Stripe." ✅ Confirmed (PRD §5, as-of 2 Jul).
  - Booking flow: "A booking holds a room for 15 minutes before payment." ✅ Confirmed (PRD §3, as-of 2 Jul).
- SOW v2 §4: "Guests pay by card only."
- SOW v2 §5: "Payments run through Braintree."
- SOW v2 §6: "Front-desk staff can view, but not edit, room rates."

Eval harness: this session has no connector tools. Every read the run needs is
given above, the run ends at its stop and nothing is pushed, so the write-tool
check passes. Draft the update.
