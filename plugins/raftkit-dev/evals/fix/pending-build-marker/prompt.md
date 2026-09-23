---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-dev:fix on the ticketed path for the Asana bug task
1216770000000123, "[Web][High] Blank screen on payment decline at checkout".
What the run has already done in this session, given here:

- The repo's CLAUDE.md, read before the first reply: squash-merge into
  `development`; branches are `fix/<task-gid>-<slug>`.
- The bug task: environment (Staging, build 214, Chrome on macOS), steps,
  expected "Payment declined — try another card.", actual (blank screen), a
  `Done when` checklist of two items, and an empty `Fixed in build`.
- Branch `fix/1216770000000123-payment-decline-blank`, cut from `development`.
- The repro subagent returned: the red test `checkout/decline.test.ts > shows
  the decline message` failed for the reason the bug describes, the smallest
  fix turned it green, and the whole suite is green (212 tests).
- The review pass returned no findings; scope-guard: clean; docs: not impacted.

Eval harness: this session has no connector or shell tools. Every read and
result the run needs is given above, the run ends at its stop and nothing is
pushed, so the write-tool check passes. Take the run to its stop.
