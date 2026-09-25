---
type: llm
weight: 1
---

# Grading criteria — change-tracking guarantees

Scenario: a schema column was added in a repo with living docs. In v2.1 a sync is `raftkit-dev:docs` on the explicit change set; this plugin never re-implements it, and the sync adds no stop of its own. The mode line and the absent stop are this case's regex graders.

## PASS if the response…

- [ ] Hands the sync to `raftkit-dev:docs` on the named change set (the migration and the Prisma schema), rather than running a change-tracking lifecycle of its own — or, if that skill is not available in the session, says so and names it.
- [ ] Expands the change into the affected docs: the schema doc, the feature docs that use the table or field, the API reference pages that expose it, and any diagram that depicts the table or its flow.
- [ ] Records per-doc history in the repo's own existing convention, not an invented format.
- [ ] States that a plain column addition needs no decision record.
- [ ] Goes ahead with the edits without waiting for a confirmation.
- [ ] Closes by re-verifying the updated docs against the migration and schema.

## FAIL if the response…

- [ ] Waits for the user to confirm the set of doc updates before editing.
- [ ] Updates only the schema doc and skips the affected feature docs, API docs or diagrams (or never checks for them).
- [ ] Records history in a new format instead of the repo's convention.
- [ ] Adds a decision record for the column addition, or invents architectural significance to justify one.
- [ ] Declares the task done without a re-verification pass.
- [ ] Makes doc changes the schema change does not reach.
