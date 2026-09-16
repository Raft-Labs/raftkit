---
description: How to use the raftkit-dev plugin — the dev workflow, every skill, and what to say to trigger it
argument-hint: [skill name or question]
---

# raftkit-dev help

The user ran `/raftkit-dev:help $ARGUMENTS`.

**If `$ARGUMENTS` names a skill or asks a question**, answer it from `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/SKILL.md` and its `references/`. **Otherwise present the overview below.**

## The dev workflow

`setup` once per repo. Then per story: `implement` takes the story URL, plans in the open, builds test-first, runs one parallel review pass, and stops once with the PR and the Asana close-out drafted. `fix` does the same for a defect or a production trace. `scope-guard`, `docs` and the simplify pass run inside that review pass and stand alone on request. Merging stays human, and no skill ticks `[AC]`, `Testing`, or closes a story.

## Skills

| Skill | What it does | Say | Not for |
| --- | --- | --- | --- |
| `docs` | Checks whether a change set leaves the documentation accurate, and syncs what it touches | "do the docs still match the code?", "sync the docs for this story" | designing docs from scratch (the opt-in `raftkit-docs` plugin) |
| `fix` | Fixes a defect or a production incident: red repro test first, smallest fix to green, one review pass, one stop with the PR and the hand-back | "fix this bug <url>", "I found a bug", or a pasted Sentry trace | a feature or refactor wish (`implement`, through a story) |
| `hasura` | Scaffolds race-safe migrations with permissions YAML, applies them through the project's own targets, and queries any stage | "create a new migration", "add a hasura table", "check migration status" | editing an applied migration, or migrating a non-local stage |
| `implement` | Takes one story to a review-ready PR: plan in the open, test-first phases, one parallel review pass, one stop with the PR and the Asana close-out | "implement this story", "raise the PR", "check scope", "simplify this" | merging, ticking `[AC]` or `Testing`, or closing the story |
| `scope-guard` | Audits a branch diff against its story into BEYOND and MISSING lists, fail-closed | "check my diff against the story", "audit scope before the PR" | judging code quality, or removing code |
| `setup` | Wires a repo in one transaction: working agreement, design standard, settings, hook, CI guardrail, review config, optional PR auto-review | "set up this repo", "install the governance pack", "update the governance pack" | editing GitHub org settings, or clobbering an existing CLAUDE.md |
| `ui` | Builds a story's screens from its own designs and exact copy, every state it defines, through frontend-design and the project's stack | "build the UI for this story", "create the screens" | inventing copy, designs or tokens; backend work |

## Renamed in v2

`init` + `setup-project` + `capability-preflight` + `pr-auto-review` → `setup` · `fix-bug` + `fix-production-error` → `fix` · `pr` + `simplify` + `ultrathink` → folded into `implement` · `ui-creation` + `recipes` → `ui` · the docs design product → the opt-in `raftkit-docs` plugin.

Rules every skill inherits (one stop per run, live templates fetched once, the scope line): `/raftkit-core:help`.
