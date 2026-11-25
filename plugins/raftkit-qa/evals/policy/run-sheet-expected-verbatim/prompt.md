---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-qa:test-cases for the story "Checkout — declined card"
(task 1216770000000789). What the run reads, given here:

- Scenario: a guest pays with a card the bank declines.
- `[AC]` (1216770000000801) When the bank declines the card, the page shows "Payment declined — try another card." and keeps the cart.
- `[AC]` (1216770000000802) The guest can retry with another card without re-entering the address.
- `[AC]` (1216770000000803) A declined payment is logged with the bank's decline code.
- Edge-case rows: error — "Payment declined — try another card.", recovery: retry with another card; waiting — "Processing payment…" with a spinner; empty — N/A.
- Allowed: a guest with items in the cart. Blocked: a guest whose cart is empty is sent back to the room list.
- Subtasks: the three `[AC]`s, `Development` (not done), `Testing`, `Bugs`.
- The project's QA Sheet, "Riverside QA", holds no rows for this story.

Eval harness: this session has no connector tools. Every read the run needs is
given above. Build the test cases and the run sheet.
