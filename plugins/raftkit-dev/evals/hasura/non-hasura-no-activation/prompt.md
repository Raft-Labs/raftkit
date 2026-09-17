---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

I have a plain Node.js Express API in this repo — routes in `src/routes`, a Postgres connection via `pg`, and Jest for tests. I need to add rate limiting to the public `/api/search` endpoint so a single client can't hammer it. Can you suggest how to implement that and wire it into the existing middleware stack?
