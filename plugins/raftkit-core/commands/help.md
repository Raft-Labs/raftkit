---
description: RaftKit router — write or check a user story → raftkit-pm:story; implement a story URL → raftkit-dev:implement; fix a bug or trace → raftkit-dev:fix; set up a repo → raftkit-dev:setup; file or retest a bug → raftkit-qa:bug. Every role skill → /raftkit-pm:help, /raftkit-dev:help, /raftkit-qa:help. The shared rules and telemetry → this help.
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
| `cowork-telemetry` | The one line a pm or qa skill says to name itself, which is the only record Cowork gives that a skill ran | "Why does the skill announce itself?" / "How do I opt out in Cowork?" |

## What it does in the background

In Claude Code, telemetry hooks record which skills run and what each run costs in tokens (`RAFTKIT_TELEMETRY=off` to opt out). When delivery is stuck, session start says so, at most once a day. Cowork has no hooks, so that switch does nothing there and a pm or qa skill names itself in its first reply instead — see `cowork-telemetry`. At session start an entry map points common requests at their `raftkit-dev` skill. A `PreToolUse` shunt declines a main-session read of any file at or over the line threshold (500) and points at the `raftkit-core:bulk-reader` subagent, which answers the question on Haiku and returns cited bullets. Reads by a subagent, the bulk-reader included, are exempt; so are instruction files (`CLAUDE.md`, any `SKILL.md`, anything under `skills/`, plan records), and a read narrowed by `offset`/`limit` passes straight through. `RAFTKIT_SHUNT_MIN_LINES` moves the threshold; `RAFTKIT_SHUNT=off` turns it off.

## Three rules everyone hits

1. **One stop per run.** A skill drafts everything, then stops once before anything leaves the session. Approve to push; an edit re-presents the draft; silence pushes nothing.
2. **Live templates.** Story and bug formats come from the Asana template tasks, fetched once and reused within the conversation while they can still be quoted verbatim.
3. **Free-tier Asana only.** No dependencies, custom fields, milestones or start dates; relationships are task links.

## Your role plugin

`/raftkit-pm:help` (profiles, stories, estimates, updates) · `/raftkit-dev:help` (implement, fixes, setup) · `/raftkit-qa:help` (suites, run sheets, bugs) · `/raftkit-docs:help` (the opt-in documentation product).
