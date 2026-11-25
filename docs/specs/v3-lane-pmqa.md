# v3/lane-pmqa — PM and QA consolidation (v3 thinning, stories 11 and 12)

Source: `docs/specs/2026-11-25-raftkit-v3-thinning-proposal.md` §8, stories 11 and 12.

## Scope contract

In scope:

- **Story 11 — `feat(pm): consolidate`.**
  - (a) story's size mode moves into estimate as the N=1 case; `story/references/sizing.md` is deleted; the founder watermark and the developer-name gate stay.
  - (b) the routine skill is deleted; the deprecation-sweep prompt ships as a static asset at `plugins/raftkit-pm/assets/deprecation-sweep-prompt.md`, referenced by nothing that runs it; the meeting-notes prompt does not ship.
  - (c) meeting folds into profile (owner-gated): profile gains a "from a call" mode with cited decisions, a Profile delta and a task batch with SCOPE CHANGE flags, one stop; the meeting skill is deleted.
  - (d) status cut to ~150–300 words (house style, task-traced lines, exactly one ask); story cut to ~530–700 words across SKILL.md and references (author, amend, check).
- **Story 12 — `feat(qa): consolidate`** (owner-gated; Cowork Sheets append/update and Asana tagging unverified).
  - New skill `test-cases` replaces `suite` and `run-sheet`: keyed on the `[AC]` GID, appends rows to the QA-owned Sheet, produces a per-story numbered run sheet with expected results quoted verbatim, QA edits win, writes after one stop.
  - `bug` trimmed to ~500 words: verbatim Jam evidence, proposed judgment fields, one stop, retest mode kept; pre-submit checklist and per-field Jam mapping deleted.
- Evals of deleted skills deleted; evals of changed skills adjusted only where now wrong.

Out of scope: everything else. Help commands (lane core), `tests/budgets.json`, `tests/structure.test.sh`, other suites, README, CLAUDE.md, `skill-aliases.json`, other plugins, the eval reset (story 15).

Kept byte-identical: every `**STOP**` line, every `Can't …` line, the founder watermark, the approval-chain line, `Review, edit, send — I don't send.`, `Quiet period — no shipped items this week.`, the `Fixed in build: pending — first build containing PR #<n>` string.

## Phases

| # | Tier | Files | Tests |
|---|---|---|---|
| 1 | mechanical | `raftkit-pm/skills/estimate/*`, `story/*` (sizing.md deleted) | `estimate-totals`, `frontmatter`, `plain-language` |
| 2 | mechanical | `raftkit-pm/skills/routine/` deleted, `raftkit-pm/assets/deprecation-sweep-prompt.md`, `evals/routine/` deleted | `plain-language` |
| 3 | standard | `raftkit-pm/skills/profile/*` (call mode), `skills/meeting/` and `evals/meeting/` deleted | `cowork-telemetry`, `plain-language` |
| 4 | mechanical | `raftkit-pm/skills/status/SKILL.md`, `story/*`, `plugin.json` | `structure` (budgets), `plain-language` |
| 5 | standard | `raftkit-qa/skills/test-cases/*` new, `suite/` and `run-sheet/` deleted, eval moved | `plain-language`, `cowork-telemetry` |
| 6 | mechanical | `raftkit-qa/skills/bug/*`, `plugin.json` | `dev-flow` DF17, `structure` S14, `frontmatter` |

No executable code changes in this lane: the skills are markdown, so their tests are the stories' criteria and the existing suites.

## Integration notes

Measured on this branch after the review fixes, by `tests/structure.test.sh` (words `wc -w`, tokens its `ctoks`). The suite allows ×1.1 over each budget.

### Story 11 — pm

- **budgets.json `skills`**: delete `raftkit-pm/meeting` and `raftkit-pm/routine` (S1 fails on both until then).
- **budget `raftkit-pm/profile`**: measured SKILL.md 515 words / 759 tokens, directory 1010 words / 1461 tokens (meeting's 1230 tokens folded in). Raise `skill_md_tokens` 660 → 700, `total` 900 → 920, `total_tokens` 1020 → 1330. S4t/S5/S5t fail until then.
- `raftkit-pm/status` measured 309 words / 455 tokens (the review restored the send-decline line); can drop to `skill_md` 300, `skill_md_tokens` 420, `total` 300, `total_tokens` 420.
- `raftkit-pm/story` measured SKILL.md 462 words / 731 tokens, directory 685 words / 1085 tokens (inside the ~530–700 target); can drop `total` 1400 → 650, `total_tokens` 2340 → 1000.
- **budget `raftkit-pm/estimate` `skill_md` 570 → 590**: measured SKILL.md 639 words / 886 tokens, directory 916 / 1252. S4 fails until then (the one-story mode now states no STOP and no Drive folder).
- **budgets.json `files`**: add `plugins/raftkit-pm/assets/deprecation-sweep-prompt.md` at `words` 350, `tokens` 550 (measured 344 / 545). S18/S19 fail until then.
- `plugins` total for raftkit-pm is now 2,894 words (budget 9500); can drop.
- **skill-aliases.json**: `meeting` and `routine` no longer exist as skills. `profile` keeps `project-onboarding`; record `meeting → profile` (call mode) and `routine → deleted` in the dashboard's rename notes.
- **Renames for cross-references**: routine → deleted (deprecation-sweep prompt is `plugins/raftkit-pm/assets/deprecation-sweep-prompt.md`, run by hand); meeting → `raftkit-pm:profile` from-a-call mode; story size → `raftkit-pm:estimate` (one story is a one-feature list).
- **Help and docs that still name the old skills**: `plugins/raftkit-pm/commands/help.md` (validate.sh fails: "table references nonexistent skill(s): meeting routine"), `plugins/raftkit-core/commands/help.md`, README.md row for raftkit-pm ("size", "meeting decisions", "routines"), CLAUDE.md repo layout (`profile, story, estimate, status, meeting, routine`), the router descriptions in the skill listing, and `docs/specs/2026-09-16-raftkit-v2-design.md`.
- **marketplace.json**: the raftkit-pm entry's description must equal the new `plugin.json` description, or validate.sh fails on drift: "PM skills: the Project Profile (from sources or a client call), one story skill (author, amend, check), estimation of a feature list or one story, and the weekly client update — each with one stop before any write." Version bumped 1.2.0 → 2.0.0 (skills removed).
- **tests/frontmatter.test.sh FM5a/FM5b** pin `plugins/raftkit-pm/skills/meeting/SKILL.md`; drop it from the six-file list (the fault class is still covered by FM4 over the whole tree).
- **tests/cowork-telemetry.test.sh CW4** asserts `count -ge 9` pm+qa skills; lower the floor to 6 after story 12 (pm 4 + qa 2).
- **Eval coverage lost**: `evals/meeting/owner-collision` (SCOPE CHANGE, owner collision, spoken due date) and `evals/routine/meeting-notes-handover` are deleted with their skills. The owner-collision policy case belongs under `raftkit-pm/evals/profile/` in the story 15 eval reset.

### Story 12 — qa

- **budgets.json `skills`**: delete `raftkit-qa/suite` and `raftkit-qa/run-sheet` (S1 fails on both); add `raftkit-qa/test-cases` (S15 fails until then) at `skill_md` 480, `skill_md_tokens` 680, `total` 750, `total_tokens` 1050, `writes` true, `v2` true. Measured SKILL.md 520 words / 740 tokens, directory 812 / 1139, one STOP line.
- `raftkit-qa/bug` measured 547 words / 792 tokens, references deleted; can drop `total` 1300 → 550, `total_tokens` 1920 → 800.
- `plugins` total for raftkit-qa is now 1,319 words / 1,880 tokens (budget 5000 / 4460); can drop.
- **skill-aliases.json**: replace `"suite": "test-suite"` and `"run-sheet": "test-run-sheet"` with one entry for `test-cases` (its dashboard series continues `test-suite`; `test-run-sheet` ends). Rename notes: suite + run-sheet → `raftkit-qa:test-cases`.
- **refusals.json**: unchanged. `retest-blocked` still matches `raftkit-qa/skills/bug/SKILL.md` (S14 passes). The run-sheet's `Can't build a run sheet — …` line moved byte-identical into test-cases; it is not pinned in refusals.json today.
- **marketplace.json**: the raftkit-qa entry's description must equal the new `plugin.json` description: "QA skills: per-story test cases in a QA-owned Sheet with a manual run sheet, and one bug skill that files from Jam evidence and retests fixes — each with one stop before any write." Version bumped 1.2.0 → 2.0.0.
- **Help and docs that still name the old skills**: `plugins/raftkit-qa/commands/help.md` (suite, run-sheet), `plugins/raftkit-core/commands/help.md` ("suites, run sheets, bugs"), README.md raftkit-qa row, CLAUDE.md repo layout (`suite, run-sheet, bug`), `docs/specs/2026-09-16-raftkit-v2-design.md`.
- **tests/frontmatter.test.sh FM5a/FM5b** also pin `plugins/raftkit-qa/skills/run-sheet/SKILL.md`; with meeting gone, the six-file list becomes four.
- **tests/cowork-telemetry.test.sh CW4**: 6 pm+qa skills remain; lower the floor from 9 to 6.
- **Evals**: `evals/suite/resync-changed-rows` deleted with its skill. `evals/run-sheet/verbatim-expected-and-gaps` moved to `evals/test-cases/` because plain-language PL17 requires every skill to have a skill-fired case; its stop grader is now `count:1` (test-cases writes after one stop) and the prompt carries `[AC]` GIDs.
- **Unverified in Cowork** (owner gate): Sheets append/update and Asana tagging. test-cases checks for an append or update tool before reading; none → it says so in the first reply and hands back the run sheet and rows as one `csv` block with no stop, consistent with the rules' write-tool gate. A project with no QA Sheet gets `<project> QA` from a CSV upload under the same stop. bug already has QA apply every tag by hand.

### Cross-lane

- **Discoverability of the hand-run prompt**: the README raftkit-pm row and the merged pm help text should name `plugins/raftkit-pm/assets/deprecation-sweep-prompt.md` as a hand-run prompt (no skill runs it).
- **Version collision with lane core**: raftkit-pm and raftkit-qa `plugin.json` are at 2.0.0 on this branch. Lane core's `commands/` deletion touches the same plugin dirs; it must not re-bump, and the merge keeps 2.0.0.
- **PM owner decision: profile call-mode routing.** Fixed on this branch: a call is a valid source for a first build; call mode runs only when the PM asks for decisions or tasks and a Profile exists. Asked for decisions or tasks with no Profile, the byte-identical `Can't extract — no Project Profile for this project. Run raftkit-pm:profile first, then re-run.` still shows and points back at profile itself. The owner decides whether that line is reworded (it is not pinned in refusals.json).
