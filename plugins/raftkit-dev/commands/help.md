---
description: How to use the raftkit-dev plugin — the dev workflow, every skill, and what to say to trigger it
argument-hint: [skill name or question]
---

# raftkit-dev help

The user ran `/raftkit-dev:help $ARGUMENTS`. You are the guide to the **raftkit-dev** plugin — RaftLabs' developer workflow for Claude Code.

**If `$ARGUMENTS` names a skill or asks a question:** answer that specifically. Read `$CLAUDE_PLUGIN_ROOT/skills/<skill>/SKILL.md` (and its `references/`) as the authority — never answer about a skill from memory alone.

**Otherwise, present the overview below.** First list the directories in `$CLAUDE_PLUGIN_ROOT/skills/` and reconcile: if a skill exists that isn't in this table (or one listed here is gone), say so and describe it from its SKILL.md — the installed skills are the source of truth, not this page.

## What this plugin is

The RaftLabs way of building: **Spec-Driven + Test-Driven, human-in-the-loop at every gate.** The Asana story is the contract — its `[AC]` subtasks are the definition of done, its Out-of-scope list is a hard exclusion. Nothing beyond the story, nothing missing from it. These skills orchestrate proven engines (superpowers, code-simplifier, pr-review-toolkit, security-guidance, CodeRabbit); they rebuild nothing.

## The core loop

```
init  (once per repo — capability check, governance pack, repo config)
   ↓
implement <story-url>
   Gate 0 story readiness → plan + decomposition table → Gate 1 dev approves
   → spec file written (no spec, no code) → TDD phases via scoped subagents
   → simplify → security → lint + suite → Gate 2 scope-guard + CodeRabbit
   ↓
pr  (squash-target PR, commitlint title, automated review layers, then human)
```

Merging is always human. The skills never merge, never close stories.

## Skills

| Skill | Use it when | Say |
| --- | --- | --- |
| `init` | First time opening a repo with raftkit-dev — or checking one for drift | "init this repo" |
| `implement` | Taking one ready Asana story to a review-ready PR | "implement this story: \<url\>" |
| `scope-guard` | Auditing your diff against the story before a PR | "run scope-guard" |
| `simplify` | Stripping over-engineering after phases complete | "run the simplify pass" |
| `pr` | Raising the house-convention PR + automated review | "raise the PR" |
| `fix-bug` | A bug needs fixing — an assigned Asana bug, or one you found yourself | "fix this bug: \<bug-url\>" · "I found a bug — \<what's broken\>" |
| `fix-production-error` | You have a Sentry/CloudWatch/Crashlytics stack trace | paste the trace + "fix this production error" |
| `ui-creation` | Building the UI phase of a story with UI scope | "build the UI for this story" |
| `setup-project` | Re-running the governance pack on its own (init calls this too) | "set up this repo" |
| `recipes` | Consulted automatically for auto-update / review-prompt / native-UI patterns and web defaults | (rarely invoked directly) |

## Rules that always apply

- **TDD everywhere, bugs included** — failing test first; no red test, no fix.
- **Scope is a hard line** — improvements you spot become board proposals, not diff additions.
- **Pre-flight gates** — broken baseline = no edits; failed lint/tests freeze everything else.
- **Asana writes are draft → approve → push** (raftkit-core write-protocol), free-tier features only.

## Where things live

Board: Asana project `raftkit` (gid `1216551447756315`) · PRD: linked from the board's project description · Shared rules and constants: the `raftkit-core` plugin (auto-installed). For PM skills see `/raftkit-pm:help`; for QA see `/raftkit-qa:help`.

Close by asking which skill they want to start with, or point them at `implement` if they have a ready story.
