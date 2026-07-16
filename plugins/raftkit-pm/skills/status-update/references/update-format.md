# Status-update draft format

The deliverable is a client-ready update — written to send as-is, no placeholders.
House voice: sharp, direct, semi-formal, no filler ("Great news", "Just wanted to
reach out", "As you know" are all banned). English by default; another language
only on request.

## Shape

A short lead line naming the project and the range, then up to four sections in
this order. Omit a section that has no items rather than printing an empty header —
except the closing ask, which is always present.

1. **Shipped** — completed in range. One line each: what it delivers in client
   terms, not the task title verbatim.
2. **In progress** — active work. One line each; say what is moving, not "ongoing".
3. **Blocked** — each line carries all three, or it is not a usable blocked line:
   - **blocker** — what is stopping it;
   - **owner** — who has the next move (often the client);
   - **next step** — the specific action that unblocks it.
   Bad news always arrives with a next step. If the board does not record the owner
   or the next step, write it as unclear on the board and ask the PM to confirm —
   never invent one.
4. **Decisions needed** — each item states the decision and why it matters now.

## The one closing ask

Every update ends with exactly one ask or decision. When several decisions are
open:

- rank them by what blocks the most / is most time-sensitive;
- lead the Decisions-needed section with the top one;
- make the closing line that same single ask, phrased as a yes/no or a pick-one so
  the client can answer in a sentence.

Never end with zero asks, and never end with a list of asks. One.

## Traceability

Every line in the draft maps to a board item — a task or a task comment — from the
read in range. If a claim has no source on the board, it does not go in the draft.
This is what keeps the update honest: no invented progress, no optimistic
rounding.

## Empty and thin weeks

- **Empty** (no activity in range): lead with the quiet-period line (the exact
  string is in SKILL.md's Empty edge case), note anything genuinely in flight only
  if the board shows it, and close with the standing ask (defined in SKILL.md's
  Empty edge case). Do not manufacture progress to fill the space.
- **Thin** (little activity): report exactly what moved, plainly. Do not pad one
  shipped item into a paragraph. The honesty is the point — a thin week stated
  plainly beats a padded one every time.

## Ending line

Every draft ends by handing control back to the PM with the never-send handoff
line (the exact string lives in SKILL.md's "The one rule that governs everything"
section). The skill produces the draft and stops here — it never sends.
