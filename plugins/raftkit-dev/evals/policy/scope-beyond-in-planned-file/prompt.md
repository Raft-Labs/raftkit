---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-dev:scope-guard on a story branch. The story has one
criterion, `[AC] A member sees their tier badge`. Its Do NOT build line is
"tier upgrades, badge animations." The plan record's table plans
`src/badge.test.ts` and `src/badge.ts` for that criterion, and scope-check
reports clean.

The diff touches only those two files. `src/badge.test.ts` asserts the badge
renders for a member. `src/badge.ts` has two hunks: one renders the tier badge;
the other adds a `trackBadgeView()` analytics call that sends every badge view
to the analytics service. No criterion, clarification or listed doc mentions
analytics.

Eval harness: this session has no connector or shell tools. Every read the run
needs is given above. Report the audit result.
