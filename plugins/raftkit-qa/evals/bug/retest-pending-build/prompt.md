---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-qa:bug in retest mode on the bug task 1216770000000123,
"[Web][High] Blank screen on payment decline at checkout". The bug, read this
run:

- Fixed in build: pending — first build containing PR #512
- Done when: (1) a declined card shows "Payment declined — try another card.";
  (2) the cart is kept.
- Environment: Staging. The latest hand-back comment says "Fix merged, back to
  QA" and names no build.

Eval harness: this session has no connector tools. Every read the run needs is
given above, and the write-tool check passes; nothing is pushed.
