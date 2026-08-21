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
brainstorm           → an idea thought through into a spec doc (when there isn't one)
   ↓
user-story           → template-perfect story into a named Asana task
  (or story-skill-generator → a reusable <project>-user-story skill)
   ↓
story-readiness      → PASS / NOT READY gate before any dev sees it
   ↓
hand to raftkit-dev  → /implement refuses stories that fail readiness
   ↓
gap found downstream → user-story amend mode: extend the story in place,
                       tag its followers, re-run readiness
```

Alongside: `status-update` (weekly client draft), `meeting-decisions` (calls → decisions + tasks; scheduled version available, pending sign-off), `estimation` (a whole feature list → FE/BE/QA hours in a Sheet, founder-gated).

## Skills

| Skill | Use it when | Say | Not for |
| --- | --- | --- | --- |
| `project-onboarding` | New project, or new sources arrived | "onboard project X with this PRD and these emails" | Writing stories or updates — it only builds the profile they read |
| `brainstorm` | A feature idea with no spec behind it yet | "brainstorm this feature into a spec doc" | A feature that already has a spec — go straight to `user-story` |
| `user-story` | Writing one story into an Asana task, sizing one story, or amending a story that already exists | "write the story for password reset into \<task-url\>" · "size this story" · "extend \<task-url\> with the onboarding changes" | A whole feature list for a proposal — that's `estimation` |
| `story-skill-generator` | A project needs its own baked story skill | "generate the story skill for project X" | A one-off story — that's `user-story` |
| `story-readiness` | Checking a story before dev handoff | "is this story ready? \<url\>" | Fixing the story — it audits only; amends are `user-story`'s |
| `status-update` | Weekly client update from the board | "draft the client update for project X" | Meeting capture — that's `meeting-decisions` |
| `meeting-decisions` | Turning a call into decisions + tasks, or setting up the scheduled version [^routine] | "extract decisions from \<recording\>" · "set up the meeting notes routine for project X" | Client-facing updates — that's `status-update` |
| `estimation` | A whole feature list priced into FE/BE/QA hours for a proposal | "estimate this feature list" · "we need hours for the proposal" | Sizing one story — that's `user-story` |
| `deprecation-sweep` | Setting up the scheduled watch for third-party service notices (deprecations, end-of-support, price changes) | "set up the deprecation sweep" | Acting on a flag — the routine only reads and reports; fixes and client forwards are yours |

[^routine]: The scheduled routine writes to Asana unapproved — not to be switched on until the founders sign off the unattended-write decision.

## Rules that always apply

- **Nothing is written without your approval** — every outward write (Asana, Drive docs, files) and client-facing draft is draft → approve → push. One pending exception: the `meeting-decisions` scheduled routine, not to be switched on until the founders sign it off.
- **No invented facts** — every claim cites a source; gaps stay ❓ and get asked, not guessed.
- **Scope changes are flagged, never absorbed** — out-of-scope client asks are labelled SCOPE CHANGE.
- **Estimates are never client commitments** — every output carrying an effort number, `estimation` feature-list hours and `user-story` sizing alike, opens with the founder-review watermark.
- **Asana free tier only** — relationships are task links, not dependency features.
- **Stories carry the WEESLD frame, not a test-case list** — `user-story` answers one row per edge state (Waiting, Empty, Error, Success, Limits, Defaults — Error mandatory) and maps each to an `[AC]`. Case-level test enumeration is `raftkit-qa`'s job, built from the profile and docs. So a story with every WEESLD row answered is complete even without an exhaustive scenario list — but a blank WEESLD row is a readiness defect, and a state QA finds uncovered comes back through `user-story` amend mode.
- **Output quality tracks input context** — hand a skill everything you have, unordered, all of it; a strong source doc is the difference between 20+ cited ACs from one command and a skill that asks. Where sources are thin the skills ask (❓), never guess — so time spent gathering sources beats time spent correcting output.

## Where things live

Board: Asana project `raftkit` (gid `1216551447756315`) · Format authority: the live Feature Template (gid in raftkit-core workflow-constants) · Shared rules: `raftkit-core` (auto-installed). For dev skills see `/raftkit-dev:help`; for QA see `/raftkit-qa:help`.

**Project context lives in the Project Profile** — the one tagged (✅/⚠️/❓) source-of-truth doc `project-onboarding` produces; every other skill reads from it and cites it. On completion, `project-onboarding` names exactly where it wrote the profile — that location is what you point later skills at. And context survives to tomorrow only if the next chat starts **in the same Cowork project**: the project's memory and instructions are what carry the profile and your working context forward; a chat started elsewhere begins blind and will re-ask.

Close by asking what they're trying to do — new project → onboarding; a feature idea with nothing written down yet → brainstorm; a feature that already has a source of truth → user-story; handoff → story-readiness; a gap found by dev or QA in a story that already exists → user-story amend mode.
