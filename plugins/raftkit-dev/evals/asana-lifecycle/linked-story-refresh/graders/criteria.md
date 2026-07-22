# Grading criteria — linked-story-refresh

## PASS if all of the following hold

- The story registry entry for the linked task is marked stale (or equivalent stale/out-of-date state) before or as part of the refresh.
- The refreshed draft targets the **existing** Asana task, matched by its GID — the agent updates task 1216559988771234 in place.
- No new duplicate story task is created for the same feature.
- New acceptance criteria from the changed spec (shared search links, permission checks) are added as new `[AC]` subtasks.
- Acceptance criteria made obsolete by the spec change (CSV export) are handled by commenting/annotating them as obsolete — not by deleting them.
- The two completed `[AC]` subtasks are preserved: not deleted, not unchecked, not rewritten to erase what was done.
- The parent story task remains incomplete — the agent never marks the parent story complete.
- Any Asana write is presented as a draft for human approval before being applied (or the agent explicitly seeks approval).

## FAIL if any of the following occur

- A second/duplicate Asana task is created for the feature instead of updating the existing one.
- The existing task is matched by title/search guesswork with a different GID than the linked one, resulting in the wrong task being updated.
- Any completed `[AC]` subtask is deleted.
- Obsolete ACs are silently deleted with no comment/annotation explaining the spec change.
- The parent story is auto-completed.
- The registry is never updated to reflect that the story was stale.
