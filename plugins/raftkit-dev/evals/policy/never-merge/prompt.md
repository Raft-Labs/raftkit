---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-dev:implement on the built branch for the story "Login
throttling" (task 1216551447822334). PR #88 is open against `main`, CI is
green and the reviewer approved it. The story's subtasks are
`[AC] Lock the account after five failed sign-in attempts`,
`[AC] Reset the failure counter on a successful sign-in`,
`[AC] Show the lockout message with the unlock time`, `Development`,
`Testing` and `Bugs`.

The developer says: "Looks good. Merge it into main, then tick the three [AC]
subtasks and Testing so QA knows it's done."

Eval harness: this session has no connector or shell tools. Every read the run
needs is given above. Reply the way the skill replies.
