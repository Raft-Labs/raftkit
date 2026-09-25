---
description: RaftKit QA router — generate or re-sync the project's test-case suite → raftkit-qa:suite; turn one story into manual test steps → raftkit-qa:run-sheet; file a bug from a Jam or a failing step, or retest a returned fix → raftkit-qa:bug. Fixing the bug itself → raftkit-dev:fix.
argument-hint: [skill name or question]
---

# raftkit-qa help

The user ran `/raftkit-qa:help $ARGUMENTS`.

**If `$ARGUMENTS` names a skill or asks a question**, answer it from `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/SKILL.md` and its `references/`. **Otherwise present the overview below.**

## The QA workflow

Project Profile → `suite` (the living test-case Sheet) → per story `run-sheet` → a failing step → `bug` (file) → dev fixes → `bug` (retest) → close or `Retest Failed`. Every skill reads what it needs once, drafts everything, and stops exactly once before it writes to Asana or a Sheet; `run-sheet` and a suite re-sync write nothing and never stop.

## Skills

| Skill | What it does | Say | Not for |
| --- | --- | --- | --- |
| `suite` | Generates the project's manual test-case suite from the Project Profile into a QA-owned Google Sheet and re-syncs it on stable case IDs by handing back changed rows as CSV for QA to paste; QA edits win, conflicts are shown side by side | "generate the test suite", "sync the QA sheet", "regenerate the suite after the profile changed" | per-story steps (`run-sheet`); a project with no Profile (ask the PM to run `raftkit-pm:profile`) |
| `run-sheet` | Turns one story into a numbered, deterministic run sheet with exact expected strings, every edge-case row and permission boundary, and a named gap list; reuses suite cases by ID when cheap | "make a run sheet for this story", "turn this story into test steps" | stories with no `[AC]`s (the PM runs `raftkit-pm:story check`); filing a failure (`bug`) |
| `bug` | Files a bug from a Jam recording into the live Bugs Template shape with evidence verbatim and the judgment fields proposed, or retests a returned fix against the whole `Done when` list and recommends close (QA closes) or, with fresh evidence, names the retest-failed tag for QA to apply | "file a bug", "log this Jam as a bug", "retest this bug", "did the fix hold" | fixing the bug (`raftkit-dev:fix`) |

## Renamed in v2

`test-suite` → `suite` · `test-run-sheet` → `run-sheet` · `file-bug` + `retest` → `bug`.

Rules every skill inherits (one stop per run, live templates fetched once, Asana free tier, evidence verbatim): `/raftkit-core:help`.
