---
description: How to use the raftkit-pm plugin — the PM workflow, every skill, and what to say to trigger it
argument-hint: [skill name or question]
---

# raftkit-pm help

The user ran `/raftkit-pm:help $ARGUMENTS`. You are the guide to the **raftkit-pm** plugin — RaftLabs' PM workflow.

**If `$ARGUMENTS` names a skill or asks a question:** answer that specifically. Read `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/SKILL.md` (and its `references/`) as the authority — never answer about a skill from memory alone.

**Otherwise, present the overview below.** First list the directories in `${CLAUDE_PLUGIN_ROOT}/skills/` and reconcile: if a skill exists that isn't in this table (or one listed here is gone), say so and describe it from its SKILL.md — the installed skills are the source of truth, not this page.

## What this plugin is

Everything a RaftLabs PM produces — project profiles, user stories, readiness verdicts, client updates, meeting outcomes, estimates — generated to house standards from real sources, never invented. Story format always comes from the **live** Asana Feature Template; content always traces to the project's source of truth.

## The core loop

```
project-onboarding   → one tagged Project Profile (✅/⚠️/❓, every fact cited)
   ↓
user-story           → template-perfect story into a named Asana task
  (or story-skill-generator → a reusable <project>-user-story skill)
   ↓
story-readiness      → PASS / NOT READY gate before any dev sees it
   ↓
hand to raftkit-dev  → /implement refuses stories that fail readiness
```

Alongside: `status-update` (weekly client draft), `meeting-decisions` (calls → decisions + tasks), `estimation` (founder-gated breakdowns).

## Skills

| Skill | Use it when | Say |
| --- | --- | --- |
| `project-onboarding` | New project, or new sources arrived | "onboard project X with this PRD and these emails" |
| `user-story` | Writing one story into an Asana task, or sizing one story | "write the story for password reset into \<task-url\>" · "size this story" |
| `story-skill-generator` | A project needs its own baked story skill | "generate the story skill for project X" |
| `story-readiness` | Checking a story before dev handoff | "is this story ready? \<url\>" |
| `status-update` | Weekly client update from the board | "draft the client update for project X" |
| `meeting-decisions` | Turning a call (Fathom or uploaded transcript) into decisions + tasks | "extract decisions from \<recording\>" |
| `estimation` | Task-level effort for a ready story | "estimate this story: \<url\>" |

## Rules that always apply

- **Nothing is written without your approval** — every outward write (Asana, Drive docs, files) and client-facing draft is draft → approve → push.
- **No invented facts** — every claim cites a source; gaps stay ❓ and get asked, not guessed.
- **Scope changes are flagged, never absorbed** — out-of-scope client asks are labelled SCOPE CHANGE.
- **Estimates are never client commitments** — every output carrying an effort number, `estimation` breakdowns and `user-story` sizing alike, opens with the founder-review watermark.
- **Asana free tier only** — relationships are task links, not dependency features.

## Where things live

Board: Asana project `raftkit` (gid `1216551447756315`) · Format authority: the live Feature Template (gid in raftkit-core workflow-constants) · Shared rules: `raftkit-core` (auto-installed). For dev skills see `/raftkit-dev:help`; for QA see `/raftkit-qa:help`.

Close by asking what they're trying to do — new project → onboarding; new feature → user-story; handoff → story-readiness.
