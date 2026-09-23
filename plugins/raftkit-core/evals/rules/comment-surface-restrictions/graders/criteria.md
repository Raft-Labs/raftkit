---
type: llm
weight: 1
---

# Grading criteria — comment-surface-restrictions

Scenario: a richly structured update (headings, a table, a horizontal rule in the source draft) is to go up as an Asana task comment, the most restricted rich-text surface: no headings, no rules, no images, no tables. Tag checks inside the payload are this case's regex graders.

## PASS if ALL of the following hold

- Section titles from the draft ("Sprint Checkpoint", "Progress by area", "Blockers", "Next up") become bold labels.
- The per-area breakdown becomes a list, one item per area carrying its status and owner.
- All information survives: every area, status and owner, every blocker, every next step.
- The comment is drafted for task 1216551447800123 and shown in full before anything is posted.

## FAIL if ANY of the following occur

- Information is dropped during restructuring — e.g. the owner column disappears, a blocker or next step is missing.
- The content is aimed at a different surface (e.g. the task description) without the user asking.
- The reply refuses, claims the content cannot be posted, or claims it was posted.
