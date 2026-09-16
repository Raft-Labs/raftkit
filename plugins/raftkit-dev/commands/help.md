---
description: How to use the raftkit-dev plugin — the dev workflow, every skill, and what to say to trigger it
argument-hint: [skill name or question]
---

# raftkit-dev help

The user ran `/raftkit-dev:help $ARGUMENTS`.

**If `$ARGUMENTS` names a skill or asks a question**, answer it from `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/SKILL.md` and its `references/`. **Otherwise present the overview below.**

## The dev workflow

`setup` once per repo, then per story: `implement` takes the story URL, plans in the open, builds test-first, runs one parallel review pass, and stops once with the PR and the Asana close-out drafted. `fix` does the same for a defect or a production trace. `scope-guard` and `docs` run inside that pass and stand alone on request. Merging stays human.

## Skills

| Skill | What it does | Say |
| --- | --- | --- |
| `docs` | Checks whether a change set leaves the documentation accurate and syncs what it touches | "do the docs still match the code?", "sync the docs for this story" |
| `fix-bug` | Fixes a defect with a failing test first (being merged into `fix`) | "fix this bug <url>", "I found a bug" |
| `fix-production-error` | Works a production trace with incident discipline (being merged into `fix`) | "fix this production error", "here is a Sentry trace" |
| `hasura` | Scaffolds race-safe Hasura migrations, permissions and schema snapshots | "create a new migration", "add a hasura table" |
| `implement` | Takes one story to a review-ready PR (being rewritten for one stop) | "implement this story", "run /implement <story-url>" |
| `pr` | Raises the PR (being merged into `implement`) | "raise the PR" |
| `recipes` | The baked-in feature recipes and web defaults (being merged into `ui`) | not user-invocable |
| `scope-guard` | Audits a branch diff against its story into BEYOND and MISSING lists | "check my diff against the story", "audit scope before the PR" |
| `setup` | Wires a repo in one transaction: working agreement, design standard, settings, hook, CI, review config | "set up this repo", "install the governance pack" |
| `simplify` | The minimalism pass (being merged into `implement`) | "simplify this" |
| `ui-creation` | Builds a story's UI from its designs and exact copy (being renamed `ui`) | "build the UI for this story" |
| `ultrathink` | Proportionate planning (being merged into `implement`) | "ultrathink", "make a plan" |

Skills marked "being merged" still work; they are consolidated in the next v2 step. Rules every skill inherits (one stop per run, live templates, the scope line): `/raftkit-core:help`. Designing project documentation from scratch is the opt-in `raftkit-docs` plugin.
