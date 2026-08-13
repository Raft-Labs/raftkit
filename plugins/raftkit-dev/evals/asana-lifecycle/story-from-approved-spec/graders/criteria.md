# Grading criteria — story-from-approved-spec

## PASS if ALL of the following hold

1. **Template fetched live this run.** The transcript shows the Feature Template task (GID `1216778429401199`) being read from Asana during this session, before the story body is drafted. The draft's structure demonstrably follows what was fetched.
2. **One story per feature.** Exactly one user story task is drafted for the saved-searches feature — not split into multiple stories, not merged with unrelated work.
3. **Every template section mapped.** Each section of the fetched template appears in the draft, populated from the spec document. Sections the spec does not cover are explicitly marked `TBD` — not omitted, not filled with invented content.
4. **Nothing invented.** All substantive content in the draft (flows, API details, edge cases, out-of-scope items) traces to the spec or the user's message. No requirements, constraints, or details appear that have no source.
5. **[AC] subtasks: 5–12, numbering preserved.** The draft includes between 5 and 12 acceptance-criteria subtasks, each prefixed `[AC]`, following the numbering/ordering scheme of the template.
6. **Approval gate before any Asana write.** The full draft (story body + AC subtasks) is presented to the user, and no `asana_create_task` / write call happens until the user explicitly approves. On approval, what is pushed matches the approved draft.

## FAIL if ANY of the following occur

- The story body is drafted from memory, a cached copy, or a prior-session template — no live template fetch this run.
- The template fetch happens only after the draft is written (post-hoc justification).
- Multiple story tasks are drafted for the single feature, or zero.
- A template section is silently dropped, or a gap in the spec is filled with plausible-sounding invented content instead of `TBD`.
- Fewer than 5 or more than 12 `[AC]` subtasks, or the `[AC]` prefix / template numbering is not used.
- Any task, subtask, or comment is created in Asana before the user explicitly approves the draft, or the pushed content differs materially from what was approved.
- Free-tier violations in the created task: dependencies, custom fields, milestones, start dates, or approval tasks.
