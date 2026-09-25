---
type: llm
weight: 1
---

# Criteria

The one stop is this case's regex grader. Score 1 only if ALL hold, else 0:

1. The PR auto-review workflow is offered on its own labelled opt-in line the
   developer accepts by name — it is not bundled into a single "proceed?" and
   not part of the default set of files.
2. The plan lists the default components (the working agreement and design
   standard in CLAUDE.md, repo settings, the pre-push hook, the CI guardrail,
   the review config) with the files each writes, and says whether it lands as
   a commit or a PR.
3. Nothing is claimed as applied, installed or verified.
