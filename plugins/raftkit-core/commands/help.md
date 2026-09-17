---
description: How to use raftkit-core — the shared rules every RaftKit plugin runs on, and where to find the role plugins
argument-hint: [skill name or question]
---

# raftkit-core help

The user ran `/raftkit-core:help $ARGUMENTS`.

**If `$ARGUMENTS` names a skill or asks a question**, answer it from `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/SKILL.md` and its `references/`. **Otherwise present the overview below.**

## What this plugin is

raftkit-core is the rulebook the role plugins inherit. It installs automatically with any role plugin and carries no day-to-day workflow of its own.

## Skills

| Skill | What it holds | Ask it when |
| --- | --- | --- |
| `rules` | Asana GIDs and the Project Profile convention, the one human stop per run, fetch-once for live reads, the Asana HTML floor, free-tier limits, the scope line, founder escalation and the estimation watermark, story readiness, plain output | "What's the template GID?" / "Can I use Asana dependencies?" / "What's the rule on estimates?" |
| `working-agreement` | The ten-rule RaftLabs working agreement and the Module Design Standard (MDS-1…10), the text `raftkit-dev:setup` installs into a client `CLAUDE.md` | "What's rule 2?" / "What's MDS-7?" |

## What it does in the background

Telemetry hooks record which skills run and what each run costs in tokens (`RAFTKIT_TELEMETRY=off` to opt out). A `PreToolUse` shunt declines a read of any file at or over 500 lines and points at the `bulk-reader` subagent, which answers the question on Haiku and returns cited bullets — so a large file costs a summary instead of its contents. Instruction files (`CLAUDE.md`, any `SKILL.md`, anything under `skills/`, plan records) are never shunted, and a read narrowed by `offset`/`limit` passes straight through. `RAFTKIT_SHUNT_MIN_LINES` moves the threshold; `RAFTKIT_SHUNT=off` turns it off.

## Three rules everyone hits

1. **One stop per run.** A skill drafts everything, then stops once before anything leaves the session. Approve to push; an edit re-presents the draft; silence pushes nothing.
2. **Live templates, never cached.** Story and bug formats come from the Asana template tasks at run time, fetched once per run.
3. **Free-tier Asana only.** No dependencies, custom fields, milestones or start dates; relationships are task links.

## Your role plugin

`/raftkit-pm:help` (profiles, stories, estimates, updates) · `/raftkit-dev:help` (implement, fixes, setup) · `/raftkit-qa:help` (suites, run sheets, bugs) · `/raftkit-docs:help` (the opt-in documentation product).
