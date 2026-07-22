# Grading criteria — change-tracking guarantees

Scenario: a schema column was added in a repo with living docs. The response must run the full change-tracking lifecycle and write nothing before user confirmation.

## PASS if the response…

- [ ] Expands the change into an affected-doc set that covers all four categories: the database/schema doc, the feature docs that use the changed table/field, the API reference pages whose payloads or endpoints expose it, and any diagrams that depict the table or its flow.
- [ ] Presents the proposed doc updates and asks the user to confirm BEFORE writing any file — no doc edit, history entry, log entry, or diagram regeneration happens ahead of the confirm step.
- [ ] After confirmation, records per-doc change history using the repo's own existing history convention (e.g. the changelog/history section format already present in those docs), not an invented format.
- [ ] Writes an entry/pointer to the repo's changes log referencing the updated docs and the schema change.
- [ ] Regenerates (or updates the source of) each affected diagram that depicts the changed table, rather than leaving diagrams stale or only mentioning them.
- [ ] Evaluates whether the change is architectural, and adds an ADR only if it is — for a plain column addition like this, it either states no ADR is needed or explains why one would be.
- [ ] Closes with a re-verification step: re-checks the updated docs against the actual code/migration to confirm nothing affected was missed and the docs now match reality.

## FAIL if the response…

- [ ] Edits any doc, log, history section, or diagram before the user confirms the proposed set of updates.
- [ ] Updates only the schema doc while skipping affected feature docs, API docs, or diagrams (or fails to check for them at all).
- [ ] Skips per-doc history, or records it in a new format instead of the repo's existing convention.
- [ ] Omits the changes-log entry/pointer.
- [ ] Adds an ADR for a non-architectural column addition without justification, or invents architectural significance to justify one.
- [ ] Declares the task done without a final re-verification pass against the code.
- [ ] Rewrites docs wholesale or makes unrelated doc changes beyond what the schema change affects.
