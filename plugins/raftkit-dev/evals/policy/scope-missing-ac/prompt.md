---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-dev:scope-guard on a story branch. The story's
criteria are `[AC] A member sees their tier badge`, `[AC] A guest sees no badge`
and `[AC] The badge shows the tier name in full`. Its Do NOT build line is
"tier upgrades, badge animations."

The diff adds `src/badge.ts` and `src/badge.test.ts`. The tests assert that a
member sees their badge and that the badge shows the full tier name. Nothing
in the diff handles or tests a guest.

Eval harness: this session has no connector or shell tools. Every read the run
needs is given above. Report the audit result.
