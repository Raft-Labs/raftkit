---
name: working-agreement
description: The RaftLabs working agreement for AI-assisted delivery (ten rules — model tiers, small phases, visible plan, green baseline, tests from acceptance criteria, verify after, loop limit, one stop, incidents first, session hygiene) plus the Module Design Standard, as installable text. raftkit-dev:setup installs both into a client CLAUDE.md. Consult it to quote a rule or check the exact text.
user-invocable: false
---

# Working agreement

Two payloads, installed verbatim into a client repo's `CLAUDE.md` by `raftkit-dev:setup`:

| File | What it is |
|---|---|
| `references/working-agreement.md` | The ten rules. Replaces protocols 1–5, the orchestrator skill, the spec-file gate and the session-health nudge. |
| `references/design-standard.md` | The Module Design Standard, MDS-1…MDS-10, each with its diff-visible trigger and fix. pr-review-toolkit's code-reviewer scores against it from `CLAUDE.md`. |

Not installed, read here: `references/tiers.md` fixes the tier names rule 1 sorts work into, so a plan's phase table and a skill's dispatch mean the same thing.

A change is a PR here; the agreement is cleared with Ashit, and its sha256 is pinned in `tests/budgets.json`. The two-file limit in rule 2 is Ashit's value; changing it is Asana decision `1216550892331152`.

Protocol → rule: model triage → 1; decomposition and scope reduction → 2; spec gate → 3 (a record, not a stop); pre- and post-edit verification → 4, 6; loop warning → 7; production alerts → 9; session hygiene → 10. The verbatim warning strings are retired.
