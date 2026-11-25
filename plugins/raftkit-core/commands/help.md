---
description: RaftKit router by role — PM, QA and dev skills, the opt-in plugins, and the shared rules.
argument-hint: [skill name or question]
---

# RaftKit help

The user ran `/raftkit-core:help $ARGUMENTS`. If it names a skill or asks a question, answer from that skill's `SKILL.md`; core skills live under `${CLAUDE_PLUGIN_ROOT}/skills/`. Otherwise show this.

- **PM:** `raftkit-pm:profile`, `raftkit-pm:story`, `raftkit-pm:estimate`, `raftkit-pm:status`, `raftkit-pm:meeting`.
- **QA:** `raftkit-qa:test-cases`, `raftkit-qa:bug`.
- **Dev:** `raftkit-dev:setup` once per repo, then `raftkit-dev:implement` per story, `raftkit-dev:fix` per bug; `raftkit-dev:scope-guard`, `raftkit-dev:ui`, `raftkit-dev:docs` on request.
- **Opt-in:** `raftkit-hasura:hasura`, `raftkit-docs:docs-product`.

| Core skill | Holds |
| --- | --- |
| `rules` | Asana constants, one stop per run, live templates, free tier, scope line, founder escalation |
| `working-agreement` | The ten rules and the Module Design Standard `raftkit-dev:setup` installs |

Telemetry: Claude Code hooks; `RAFTKIT_TELEMETRY=off` opts out. Cowork has no hooks, so that switch does nothing there.
