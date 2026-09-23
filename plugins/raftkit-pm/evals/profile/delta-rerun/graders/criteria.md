---
type: llm
weight: 1
---

# Criteria

The stop, the project line and the absent tables are this case's regex
graders. Score 1 only if ALL hold, else 0:

1. The draft is a delta, not a rewrite: the card-only fact is now confirmed
   (⚠️ to ✅, citing SOW v2 §4), the front-desk fact is new with its tag,
   citation and as-of date, and untouched facts stay exactly as they were.
2. Stripe (PRD §5) against Braintree (SOW v2 §5) is shown as a conflict with
   both citations, left for the PM to settle — neither value is picked.
3. It names the subtasks it will overwrite (business rules, roles, integrations)
   and leaves the booking-flow subtask alone.
4. It proposes no extra comment on the parent task recording the delta: the
   write is the subtasks it names.
5. Nothing is claimed as written.
