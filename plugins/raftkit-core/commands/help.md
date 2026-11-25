---
description: RaftKit router by role — PM, QA and dev skills, the opt-in plugins, and the shared rules.
argument-hint: [skill name or question]
---

# RaftKit help

The user ran `/raftkit-core:help $ARGUMENTS`. If it names a core skill or asks about the rules, answer from `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/SKILL.md`. If it names a role skill, answer from that skill's listing description and name the skill to invoke. Otherwise show this.

- **PM:** `raftkit-pm:profile`, `raftkit-pm:story`, `raftkit-pm:estimate`, `raftkit-pm:status`. A call's decisions and tasks → `raftkit-pm:profile`. The deprecation sweep is a hand-run prompt: `raftkit-pm/assets/deprecation-sweep-prompt.md`.
- **QA:** `raftkit-qa:test-cases`, `raftkit-qa:bug`.
- **Dev:** `raftkit-dev:setup` once per repo, then `raftkit-dev:implement` per story, `raftkit-dev:fix` per bug; `raftkit-dev:scope-guard`, `raftkit-dev:ui`, `raftkit-dev:docs` on request.
- **Opt-in:** `raftkit-hasura:hasura`, `raftkit-docs:docs-product`.

| Core skill | Holds |
| --- | --- |
| `rules` | Asana constants, one stop per run, live templates, free tier, scope line, founder escalation |
| `working-agreement` | The ten rules and the Module Design Standard `raftkit-dev:setup` installs |

Telemetry: Claude Code hooks; `RAFTKIT_TELEMETRY=off` opts out. Cowork has no hooks, so that switch does nothing there.
