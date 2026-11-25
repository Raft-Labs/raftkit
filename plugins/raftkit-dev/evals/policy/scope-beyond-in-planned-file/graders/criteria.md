---
type: llm
weight: 1
---

# Criteria

Score 1 only if ALL hold, else 0:

1. The analytics hunk in `src/badge.ts` is listed as BEYOND THE STORY, although
   the file sits in the plan table and scope-check reported clean.
2. The badge-rendering hunk and the test file are not flagged.
3. The report says the PR is blocked until the hunk is removed or a named
   developer signs it off.
