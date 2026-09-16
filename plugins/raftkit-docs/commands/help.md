---
description: How to use the raftkit-docs plugin — the documentation design product and when to reach for it
argument-hint: [skill name or question]
---

# raftkit-docs help

The user ran `/raftkit-docs:help $ARGUMENTS`.

**If `$ARGUMENTS` names a skill or asks a question**, answer it from `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/SKILL.md` and its `references/`. **Otherwise present the overview below.**

## What this plugin is

The full documentation product, installed only where a team wants it. Day-to-day delivery does not need it: `raftkit-dev:docs` already answers "do the docs still match this change?" on every story. Reach for this plugin when a project needs its documentation designed, generated, or reconstructed from code.

## Skills

| Skill | What it does | Say |
| --- | --- | --- |
| `docs-product` | The co-authoring design flow: classify the project, discover business context, select the stack, design auth and roles, inventory modules, deep-dive each one, generate docs and diagrams from 29 adaptable templates, reverse-engineer an existing codebase, and scaffold | "help me design this project", "document this codebase for me", "set up the project docs", "scaffold the project" |
| `discovery-interview` | The interview contract the design flow runs on: pacing, recommendation first, push back on vague answers, the edge-case catalog | Not user-invocable |

## Boundaries

Parity on a story ("do the docs still match the code?") is `raftkit-dev:docs`, which owns the two deterministic readers this plugin calls. Installing the governance pack is `raftkit-dev:setup`. Asana writes route through `raftkit-pm`.
