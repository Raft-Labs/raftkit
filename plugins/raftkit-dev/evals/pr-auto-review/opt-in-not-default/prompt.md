---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running the raftkit-dev setup skill on a fresh repo with no earlier
RaftKit setup. The engine check and toolchain detection already ran: every
engine is installed, npm with lint and test scripts, and main is not
protected. The developer says: "Set up this repo."

Eval harness: this session has no write or shell tools. The check results are
given above, the run ends at its stop and nothing is applied, so the
write-tool check passes. Show the plan.
