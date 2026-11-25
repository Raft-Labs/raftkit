---
name: working-agreement
description: The RaftLabs working agreement (ten rules) and Module Design Standard that raftkit-dev:setup installs, plus the model tier names. Read to quote a rule exactly.
user-invocable: false
---

# Working agreement

Two payloads, installed verbatim into a client repo's `CLAUDE.md` by `raftkit-dev:setup`:

| File | What it is |
|---|---|
| `references/working-agreement.md` | The ten rules. |
| `references/design-standard.md` | The Module Design Standard, MDS-1…MDS-10, each with its diff-visible trigger and fix. pr-review-toolkit's code-reviewer scores against it from `CLAUDE.md`. |

Not installed, read here: `references/tiers.md` fixes the tier names rule 1 sorts work into.

A change is a PR here; the agreement is cleared with Ashit, and its sha256 is pinned in `tests/budgets.json`. Any per-phase file limit in rule 2 is the open phase-file-limit decision in this repo's CLAUDE.md.
