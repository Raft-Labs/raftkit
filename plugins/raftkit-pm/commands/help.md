---
description: How to use the raftkit-pm plugin — the PM workflow, every skill, and what to say to trigger it
argument-hint: [skill name or question]
---

# raftkit-pm help

The user ran `/raftkit-pm:help $ARGUMENTS`.

**If `$ARGUMENTS` names a skill or asks a question**, answer it from `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/SKILL.md` and its `references/`. **Otherwise present the overview below.**

## The PM workflow

`profile` once per project (the tagged source of truth in Asana) → `story` per feature (author, then amend as gaps come back from dev or QA; `check` for readiness; `size` for one story's hours) → `estimate` for a whole feature list at proposal time → `status` weekly → `meeting` after each client call → `routine` to schedule the notes or the deprecation sweep. Every skill reads what it needs once, drafts everything, and stops exactly once before it writes; `status`, `routine` and sizing write nothing and never stop.

## Skills

| Skill | What it does | Say | Not for |
| --- | --- | --- | --- |
| `profile` | Builds or updates the Project Profile from the sources the PM names: every fact tagged ✅/⚠️/❓ and cited, conflicts shown, deltas on re-run | "onboard this project", "build the project profile", "add this PRD to the profile" | resolving conflicts for you; reading sources you did not name |
| `story` | Authors a template-perfect story with `[AC]` subtasks, amends an existing one additively with every follower CC'd, checks readiness, sizes one story in hours | "write a user story for …", "amend this story", "is this story ready?", "how long will this take?" | a whole feature list (`estimate`) |
| `estimate` | Estimates a feature list into FE, BE and QA hour ranges with assumptions, totalled, written to one Sheet | "estimate this feature list", "hours for the proposal" | one story (`story` size); prices, quotes, dates |
| `status` | Drafts the weekly client update from the live board, ending on exactly one ask; never sends | "draft the weekly client update", "status update for <project>" | internal standups |
| `meeting` | Extracts cited decisions, scope changes and action items from one call, proposes the Profile delta and the task batch | "extract the decisions from this call", "turn this call into tasks" | a project with no Profile (run `profile`) |
| `routine` | Hands over a filled-in cloud-routine prompt for meeting notes or the deprecation sweep | "set up the meeting notes routine", "schedule the deprecation sweep" | running or creating the routine itself |

## Renamed in v2

`project-onboarding` → `profile` · `user-story` + `story-readiness` + `brainstorm` → `story` · `estimation` → `estimate` · `status-update` → `status` · `meeting-decisions` → `meeting` · `deprecation-sweep` + the meeting-notes routine → `routine`. `story-skill-generator` is retired.

Rules every skill inherits: `/raftkit-core:help`.
