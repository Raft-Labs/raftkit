---
description: How to use the raftkit-qa plugin — the QA workflow, every skill, and what to say to trigger it
argument-hint: [skill name or question]
---

# raftkit-qa help

The user ran `/raftkit-qa:help $ARGUMENTS`. You are the guide to the **raftkit-qa** plugin — RaftLabs' QA workflow.

**If `$ARGUMENTS` names a skill or asks a question:** answer that specifically. Read `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/SKILL.md` (and its `references/`) as the authority — never answer about a skill from memory alone.

**Otherwise, present the overview below.** First list the directories in `${CLAUDE_PLUGIN_ROOT}/skills/` and reconcile: if a skill exists that isn't in this table (or one listed here is gone), say so and describe it from its SKILL.md — the installed skills are the source of truth, not this page.

## What this plugin is

QA without a local dev setup: comprehensive test cases generated from the product docs and kept in a Google Sheet you edit, per-story run sheets derived from the story itself, evidence-rich bug reports pre-filled from Jam recordings, and a retest discipline where closed means verified and reopened means tracked.

## The core loop

```
test-suite        (per project — docs → cases → Google Sheet, two-way sync)
   ↓
test-run-sheet    (per story — Gherkin + [AC]s → numbered manual steps)
   ↓  a step fails
file-bug          (Jam link pre-fills the Bugs Template → bug under the story's Bugs subtask)
   ↓  dev returns "Fixed in build X"
retest            (full "Done when" + adjacent regressions → close, or Retest Failed tag)
```

## Skills

| Skill | Use it when | Say | Not for |
| --- | --- | --- | --- |
| `test-suite` | Building or refreshing the project-level suite | "generate the test suite for project X" / "sync the QA Sheet" | Steps for one story — that's `test-run-sheet` |
| `test-run-sheet` | A story's Development is done and needs testing | "make a run sheet for \<story-url\>" | Project-wide coverage — that's `test-suite` |
| `file-bug` | A run-sheet step failed | "file a bug on \<story-url\> — here's the Jam: \<link\>" | Verifying a returned fix — that's `retest` |
| `retest` | A dev handed a fix back | "retest \<bug-url\> on build X" | A new defect found mid-retest — that's `file-bug` |

## Rules that always apply

- **Stories arrive carrying the WEESLD frame, not a case list** — one answered row per edge state (Waiting, Empty, Error, Success, Limits, Defaults), by design; case-level depth is created here: `test-suite` enumerates from the profile and docs, `test-run-sheet` expands the story's own states into steps and flags any state the story leaves uncovered. A flagged gap routes back to the PM through `user-story` amend mode — never absorbed silently.
- **One bug per ticket** — unrelated defects in one recording become separate tickets.
- **Severity and priority are different axes** — you'll be asked for each separately.
- **Evidence before everything** — errors quoted verbatim; the Retest Failed tag is never applied without fresh evidence.
- **The template is the contract both ways** — bugs missing steps/environment bounce back; fixes missing "Fixed in build ___" bounce back too.
- **Nothing is filed without your approval** — every bug and comment is draft → approve → push. Asana free tier only.

## Where things live

Board: Asana project `raftkit` (gid `1216551447756315`) · Format authority: the live Bugs Template (gid in raftkit-core workflow-constants) · Shared rules: `raftkit-core` (auto-installed). For PM skills see `/raftkit-pm:help`; for dev see `/raftkit-dev:help`.

Close by asking where they are in the loop — new project → test-suite; story to test → test-run-sheet; failure in hand → file-bug; fix returned → retest.
