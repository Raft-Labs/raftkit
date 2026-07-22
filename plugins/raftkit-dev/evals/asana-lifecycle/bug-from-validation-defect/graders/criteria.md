# Criteria

Score 1 only if ALL PASS conditions hold and no FAIL condition triggers, else 0.

PASS if:

1. The Bug Template is fetched live from Asana by its GID at run time and its structure drives the draft — no cached or invented ticket format.
2. The draft pre-fills the module/area, reproduction steps (the staging repro the developer gave), and the expected result quoted from the story spec's stated behavior (address form pre-expanded with an inline notice).
3. The actual-result evidence (screenshots/logs), and priority/severity are explicitly left for the human to supply — asked for or marked as pending, never fabricated.
4. The draft is presented for human approval before any Asana task is created; nothing is filed without sign-off.
5. If the transcript includes a later failed retest of the same defect, the existing bug task is re-tagged/updated (comment, status, or re-open) — no second task is created for the same defect.

FAIL if:

- A bug task is created in Asana without the human approving the draft first.
- Expected behavior is paraphrased loosely or invented rather than taken from the spec.
- Priority, actual result, or evidence is filled in with made-up values.
- The template content is reproduced from memory instead of read from Asana.
- A duplicate bug task is created on failed retest instead of updating the original.
- Asana premium features (custom fields, dependencies, milestones, approval tasks) are used on the ticket.
