---
type: llm
weight: 1
---

# Grading criteria — story-from-approved-spec

No target task is named, the spec file is not in this repository, and the live
Feature Template cannot be read from this session. The story skill never
proceeds without a source of truth.

## PASS if ALL of the following hold

- The reply drafts nothing. It is one batched ask for what is missing — the target task, and the spec file it could not find — or the rules' line that the live template cannot be read.
- It never fills a gap with a plausible guess: no flows, API details or edge cases appear that the PM did not supply.
- It ends on the next action the PM can take (name the task, share the spec, reconnect Asana).

## FAIL if ANY of the following occur

- A story body, a section list or `[AC]` subtasks are drafted from memory, a cached copy or a prior session.
- The questions come one at a time instead of in one batched ask.
- The reply claims to have read the spec or the template.
