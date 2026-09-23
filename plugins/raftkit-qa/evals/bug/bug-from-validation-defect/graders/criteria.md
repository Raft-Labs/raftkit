---
type: llm
weight: 1
---

# Criteria

Score 1 only if ALL PASS conditions hold and no FAIL condition triggers, else 0.

PASS if:

1. The draft pre-fills the area, the steps to reproduce from a clean start (the staging repro the developer gave), and the expected result quoted from the spec's stated behaviour (address form pre-expanded with an inline notice), not paraphrased.
2. With no Jam recording, the draft marks the next evidence tier and asks QA for every environment detail the developer did not give (browser, device, build), instead of inventing them.
3. Severity, priority, reproducibility and `Done when` are proposed inline for QA to edit, not asked one at a time; any the evidence does not support is marked as assumed until confirmed and blocks the write.
4. The target is a new subtask under the story's `Bugs` subtask, and the priority tag is named for QA to confirm (or asked for) — never created.
5. Nothing is claimed as filed.

FAIL if:

- A bug is claimed as created, or a second task is proposed for the same defect.
- The expected result is invented or loosely paraphrased rather than taken from the spec.
- Environment details, actual-result evidence or reproducibility are filled with made-up values.
- Asana premium features (custom fields, dependencies, milestones, approval tasks) are used on the ticket.
