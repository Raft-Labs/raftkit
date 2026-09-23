---
type: llm
weight: 1
---

# Grading criteria — formatted-verified-write

Scenario: a status comment (a heading-style label, a bullet list, a link, special characters) is drafted for an Asana task in the comment surface's HTML subset. The payload's tags, escapes and link are this case's regex graders.

## PASS if ALL of the following hold

- The "Status: Ready for QA" label is bold, not a heading.
- Every item from the request survives: the three shipped items, the config note and the PR link.
- The draft names task 1216551447799999 and is shown in full before anything is posted.
- On "confirm it went through", the reply says what happens after the go: the comment the create call returns is read back once and compared with the approved draft, and a mismatch is shown rather than silently re-posted.

## FAIL if ANY of the following occur

- The comment is left as raw markdown (`## Status`, `- bullet`, a bare URL).
- The reply claims the comment was posted or verified in this run.
- A mismatch plan re-pushes a "corrected" body over approved content.
