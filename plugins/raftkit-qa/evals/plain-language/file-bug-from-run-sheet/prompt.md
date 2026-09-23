---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
tags: [needs-live-template]
---

You are running raftkit-qa:bug in file mode. QA just ran the manual run sheet for the
"Checkout" story on web, and step 4 failed:

- Expected (quoted from the story): "Payment declined — try another card."
- Actual: the screen went blank, no message, no way back to the cart.
- Jam recording: console shows `TypeError: cannot read properties of
  undefined (reading 'code')`; no failed network requests.
- Environment: Staging, build 214, Chrome on macOS.

Eval harness: this session has no connector tools. Every read the run needs
beyond the live template is given above, the run ends at its stop and nothing
is pushed, so the write-tool check passes.

Draft the bug for QA to review before it is filed.
