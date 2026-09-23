---
type: llm
weight: 1
---

# Grading criteria — mention-no-access-fallback

Scenario: the drafted comment references one object the team can reach (the story's own `Testing` subtask) and one that may be out of reach (a task in another team's project). A mention of an object nobody here can access rejects the whole write. The markup is this case's regex graders.

## PASS if

- The cross-team reference is kept, as a plain link, and the reply says why it is not a mention.
- The comment is presented as a draft; nothing is posted without explicit approval.

## FAIL if

- The cross-team reference is dropped entirely instead of falling back to a plain link.
- The comment is claimed as posted.
