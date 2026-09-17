# RaftKit v2 — speed-first refactor

## Context

RaftKit (four Claude plugins: core, pm, dev, qa) packages the RaftLabs delivery method. It works, but every outcome is slow: a developer running `/implement` on one story passes ~15 human stops and 21 sequential steps before a PR exists; a PM writing one story hits 2-4 stops and fetches the same template three times; QA files one bug through up to 10 stops. The plugins carry 187k words of skill markdown (126k in raftkit-dev alone), and each skill loads five or six other skills before the work starts.

Aravind's brief (16 Sep 2026): complete refactor, speed first, quality preserved, all rules open to rewrite.

Decisions taken in the planning conversation:

| Decision | Ruling |
|---|---|
| Human stops inside a run | **One**: before anything leaves the session (Asana write, PR open, Sheet write). No plan-approval stop, no source-confirm stop, no model-tier stop, no spec-file gate. The plan is shown, not gated. |
| Ashit's governance pack (protocols 1-5) | **Full rewrite** into a short working agreement that keeps the intent without blocking stops. Aravind clears it with Ashit before the release to `main`. |
| Who uses it | **All three roles.** Dev (Claude Code), PM and QA (Claude apps/Cowork, no subagents, no shell). |

## Measured today (6 mapping agents, 157 tool uses, every skill read)

| Journey | Human stops | Sequential steps before deliverable | Turns | Live reads | Parallel fan-outs |
|---|---|---|---|---|---|
| Dev: story URL → PR + Asana close-out | ~15 | 21 | 45-70 | story fetched 3-4×, suite run 4-6×, pr-review-toolkit run 2× | 0 |
| PM: idea → approved story | 11-14 | 7 (author) / 12 (amend) + 18-30 interview turns | 28-45 | template fetched 3×, 14-20 Asana calls | 0 |
| QA: story → bug filed → retest | 13-16 | 6-7 per skill | 25-40 | Bugs Template fetched 2× per bug, 12-18 calls | 0 |

Root causes, in order of cost:

1. **Gate multiplicity.** Capability preflight stop, readiness refusal, plan approval, model-tier stop per phase, source-confirm checkpoint, draft-approve on every Asana write, scope-guard sign-off, PR review request. Most guard nothing the PR review would not catch.
2. **Sequential review layers, run twice.** implement runs simplify → code-reviewer → type-design-analyzer → security → lint+suite → verification walk → docs verify → scope-guard; then pr runs pr-review-toolkit again. Nothing in parallel.
3. **No cache.** "Read live, never from an earlier run" is written per skill, so one story lifecycle re-fetches the same GID 3-4 times. Every Asana write costs 3 round trips plus a confirm-back turn.
4. **Cross-reference indirection.** Every skill loads workflow-constants, house-rules, write-protocol, asana-formatting, governance-protocols and plain-language before acting.
5. **Ceremony.** SHA-bound evidence lines, verbatim strings reproduced from another file, Design Approach artifact, Docs Impact Plan, spec file plus an Asana plan comment, read-back verification, confirm-back lines, progress narration, gloss-on-first-use.
6. **Rebuilt, not orchestrated.** docs (37k words), ultrathink (13k), pr-auto-review (11.5k), discovery-interview (5.7k), capability-preflight (3k) re-implement what superpowers, pr-review-toolkit, code-simplifier and the plugin manager already do.
7. **Boilerplate.** ~3,000 words of identical guardrail text in 35 SKILL.md files; the draft→approve→push gate restated as procedure in 15; 35 skill descriptions total 4,275 words loaded into every session.

Test infrastructure: 31 suites, 856 assertions, ~70% grep pins on skill prose; 18 suites are nothing but prose pins. Three repo-wide tripwires block any shrink: PL4 (every SKILL.md must contain "Plain English out"), PL5 (≥32 SKILL.md files), PL10 (≥55 ` ```output ` blocks). The 127 outcome-graded evals have never been run; `claude plugin eval` exists in the local CLI 2.1.273, CI pins 2.1.209. Telemetry's `hooks/lib/refusals.json` pattern-matches 14 verbatim skill strings and must change in the same PRs as those strings.

Design panel (3 architects, 3 judges): all judges picked the same synthesis, which this plan is: the "strip and parallelise" run model and migration safety, plus consolidation wherever two skills share one user intent. Their corrections are folded in below and marked **(panel)**.

## Design principles (v2)

1. **One stop per run.** A run fetches, plans, builds, checks, then stops once with the complete outward draft and the exact targets, marked by a single `**STOP**` line. Approve → push everything approved. A run that writes nothing has no stop (status, run-sheet, sizing, `--plan-only`). **(panel)** A reply that edits the draft is not a go: the changed draft is re-presented; only an explicit go pushes. Merging a PR, ticking `[AC]`/Testing, closing a bug stay human.
2. **Fetch once, pass forward.** Story + ACs, template, profile, plugin inventory are fetched once per run and pasted into every subagent prompt as text (subagents never inherit context). **(panel)** The "cache" is conversation context: re-fetch when the payload can no longer be quoted verbatim (after compaction), re-read a task immediately before overwriting its description, and re-fetch the story's ACs once before the scope audit so a mid-run PM amend is caught. Templates are read-only and never need a refetch-before-write. The repo still holds zero template text.
3. **Show, don't gate.** Plans, drafts, extraction results stream as the run goes. **(panel)** In the dev journey the phase table is re-emitted with live status per phase, and `--plan-only` prints the plan and stops (a run that writes nothing), so a wrong approach can be caught before subagents edit files.
4. **Simplify, then fan out reviews once.** code-simplifier runs first on the diff (seconds, single agent, revert-on-red); then the review fan-out runs in parallel on the final diff: pr-review-toolkit's code-reviewer, type-design-analyzer, silent-failure-hunter and pr-test-analyzer dispatched directly (review-pr runs them sequentially by default), plus scope-guard, docs parity, security-guidance evidence, lint + suite. **(panel)** Reviewers run on Sonnet by default; the run reports the fan-out's token total at the stop.
5. **Skills set subagent models directly.** Haiku for mechanical, Sonnet default, session model for hard phases. No tier prompt. The plan table carries a `tier:` column per phase.
6. **No engine with its own gate runs inside a run.** **(panel)** superpowers:brainstorming and writing-plans both mandate "stop and wait for an explicit yes"; loading them re-adds the plan gate. implement plans inline (scope = ACs, phases, files, tests) and uses superpowers only where it has no gate: test-driven-development, systematic-debugging, dispatching-parallel-agents, subagent-driven-development ("continuous execution, rulings not stalls").
7. **Rules live in one place and are inherited.** One core rules doc under 500 words. Role skills say "rules apply" once and never restate plain-language, free-tier, escalation, Asana HTML, live-fetch or the gate.
8. **Skills are short.** SKILL.md ≤ 500 words, description ≤ 60 words. A reference file exists only for a lookup table, template or catalog needed at a specific step. No rationale, provenance, "Out of scope" essays or "Reference files" index sections.
9. **Batch the asks.** Judgment fields arrive pre-proposed in the draft, each marked `proposed — edit inline`; a pre-filled value that reaches an AC-bearing section carries `⚠️ assumed until confirmed` and blocks the write until confirmed. Dev-answerable gaps ride inside the plan message; phases that do not depend on an answer run; dependent phases wait. Honest count: 1 stop + at most one clarification turn.
10. **Never proceed without a source of truth.** Amend on a NOT READY story does not refuse and does not fabricate: gap rows appear in the same draft as batched questions, filled only from the PM's reply; the go is refused while any gap is blank.
11. **Orchestrate, do not rebuild.** pr-review-toolkit for review, code-simplifier for simplify, frontend-design for UI, claude-md-management for CLAUDE.md merges, skill-creator for generated skills. RaftKit owns sequencing, house format, Asana, scope.
12. **Cowork has no shell.** **(panel)** pm and qa skills never call a `.mjs`; arithmetic (estimate totals) is done by the model and shown at the stop, and CI checks the shipped examples.

## Target architecture

Four plugins stay. Inside them: **20 skills instead of 35, ~31k words instead of 187k, one stop per run, reviews in parallel, one fetch per artifact per run.**

```
.claude-plugin/marketplace.json
plugins/
  raftkit-core/   rules · working-agreement · hooks/ (telemetry, code unchanged) · help
  raftkit-pm/     profile · story · estimate · status · meeting · routine · help
  raftkit-dev/    implement · fix · scope-guard · setup · ui · hasura · docs · help
  raftkit-qa/     suite · run-sheet · bug · help
  raftkit-docs/   (optional, opt-in) the 12-phase documentation design product, moved as-is
```

### Dev journey after (target)

`/implement <story-url>`: one parallel intake turn (story + ACs · Feature Template if not in context · Project Profile · `claude plugin list --json` · baseline build/typecheck) → inline readiness check against the fetched template (5 gap types; a non-dev-answerable gap ends the run with the gap list posted as a comment draft, the one early exit) → plan shown and committed on the branch as `docs/specs/<branch>.md` (a record for resume and for scope-guard, never a gate) → phases as scoped subagents with `tier:` set by the skill, disjoint-file phases in parallel, each AC → failing test → green → re-fetch story ACs once → code-simplifier pass → **one parallel review fan-out** → fixes → lint + suite once → **STOP** with PR title, five-section description, Asana comment draft, review findings answered, token total → push PR, tick Development, post comment, one `html_text` read-back folded into the success line.

Standalone entry points on an existing branch (same skill, same in-session story): "raise the PR", "check scope", "simplify this".

| | Today | Target |
|---|---|---|
| Human stops | ~15 | 1 (+ ≤1 clarification turn) |
| Sequential steps before code | 21 | 6 |
| Story fetches | 3-4 | 2 (intake, pre-audit) |
| Full suite runs | 4-6 | 3 (baseline, post-simplify revert check, final) |
| Review passes | 9 sequential, toolkit ×2 | simplify then 1 parallel batch, toolkit ×1 |

### PM journey after (target)

`/story` on an idea or scope: one setup question (target task, scope, sources, in one ask; destination and depth defaulted with a recommendation) → template + profile fetched once → draft grounded in profile + named sources, opening with a `Sources used` block; thin sources trigger a batched interview (up to 8 related questions per turn, no explain-back turn, no recap turn, edge cases as the six house buckets) → inline readiness self-check → **STOP** with the full story body, `[AC]` subtasks, Dev/Testing/Bugs, the exact target → push. Amend: diff-first, readiness once in memory, gaps as batched questions in the same draft, one STOP, re-read the task immediately before the description write, partial failure reports what landed. Sizing: no stop, watermark first line.

| | Today | Target |
|---|---|---|
| Human stops (author) | 2-4 | 1 |
| Human stops (amend) | 4 | 1 |
| Template fetches per run | 3 | 1 |
| Interview turns (exhaustive) | 18-30 | 4-8 |

### QA journey after (target)

`/bug` with a Jam link: cheap validation first (target story named?) → Bugs Template (once per chat) + story + project tags + Jam reads (metadata, events, console, network, screenshots) in one turn → draft complete with the five judgment fields pre-proposed (`proposed — edit inline`), title in house format, checklist shown ticked; a multi-defect recording yields N drafts in one message → **STOP** → create, tag, read-back folded into the success line. Retest mode: validate build and `Done when` before any fetch; fresh evidence; itemised failures; **STOP** with close-or-fail draft and tag (create-or-ask, never silent). `/suite` conflicts resolve as one approve-all-with-exceptions prompt. `/run-sheet` writes nothing and has no stop; the suite lookup is lazy.

| | Today | Target |
|---|---|---|
| Stops per bug filed | up to 10 | 1 |
| Stops per file + retest | 13-16 | 2 |
| Bugs Template fetches per bug lifecycle (one chat) | 2 | 1 |
| Asana round trips per write | 3 + confirm turn | 2, success line inline |

## Skill inventory: keep / merge / shrink / drop

Budgets cover SKILL.md + references (executable scripts and templates excluded). `tests/budgets.json` enforces them with 10% headroom.

### raftkit-core (19.7k → ~4k words)

| v2 skill | Budget | Built from | Notes |
|---|---|---|---|
| `rules` | 500 + `references/asana-html.md` (tag matrix, conversion, mentions, read-back, partial-failure rule for multi-write batches) + `references/readiness.md` (the 5 gap types and how to derive the checklist from the fetched template; no row names, no section names) + `references/plain-language.md` (rules + banned list; glossary and Gate-N rule cut) | house-rules, write-protocol, asana-formatting, workflow-constants, story-readiness's checklist | Constants table (the only place GIDs appear). The one gate and what counts as a go. Session-cache rule with its invalidation trigger. Free tier. Scope line. Escalation + estimation chain + watermark. Story-gap loop in one paragraph. find-skills in one line. Nothing about telemetry, pr-auto-review, or open questions. |
| `working-agreement` | 200 + `references/working-agreement.md` (≤300, installable, sha256-pinned in tests) + `references/design-standard.md` (MDS-1…10, kept verbatim) | governance-protocols, design-standard | Text below, with the "dropped and why" list for Ashit. |
| `hooks/` | code unchanged; `lib/refusals.json` rewritten to the v2 strings with a `legacy_name` map; new events `gate_shown`, `go`, `edit`, `abandon` | — | The before/after comparison on the pilot needs these events. |
| `commands/help.md` | 300 | help | Drop the directory-reconcile step and the rules restatement. |
| **dropped** | | discovery-interview | Its pacing rules were the PM plugin's biggest turn multiplier. The six edge-case buckets go into `rules/references/readiness.md`; push-back and proactive catalogs are dropped. |

### raftkit-pm (30k → ~8.5k words)

| v2 skill | Budget | Built from | Notes |
|---|---|---|---|
| `profile` | 900 + profile-format ref | project-onboarding | One STOP that lists the subtasks it will overwrite. On an Asana timeout, look the profile task up by name before any retry. No per-source narration, no delta comment after the write. |
| `story` | 1,400 + `references/sizing.md` (150) + `references/interview.md` (the eleven lenses as a 20-line checklist) | user-story (author, amend, sizing), story-readiness, brainstorm | Modes by target state: author / amend / check / size. Readiness is an inline self-check (from core `readiness.md`) and a standalone `check` mode. |
| `estimate` | 1,200 + sheet-output ref | estimation | Keep the watermark and developer-name gates; feature echo-back merges into the draft; totals computed and shown by the model, checked in CI over the shipped examples. |
| `status` | 600 | status-update | Already lean. No stop (writes nothing). |
| `meeting` | 900 + extraction ref | meeting-decisions (minus routine) | Extraction + profile delta + task batch as one draft, one STOP, partial-failure rule from core. |
| `routine` | 500 + 2 prompt templates | meeting-decisions/scheduled-routine, deprecation-sweep | Hands over a filled routine prompt (meeting notes or deprecation sweep). The founders' unattended-write decision stated once here. |
| **dropped** | | story-skill-generator | A per-project fork of user-story built to avoid re-reading the profile; the session cache removes the reason. Content retrievable from `archive/v1`. |

### raftkit-dev (126.5k → ~13k words + scripts/templates; docs product moves out)

| v2 skill | Budget | Built from | Notes |
|---|---|---|---|
| `implement` | 1,500 + `references/flow.md` + `references/pr-format.md` | implement, pr, simplify (as the pre-fan-out pass), ultrathink (plan step), capability-preflight (one-line engine check) | Story → PR, one STOP. Standalone entries: raise the PR, check scope, simplify this. `--plan-only`. Plan committed on the branch as a record. Reads the working agreement from the client CLAUDE.md, not from another skill. |
| `fix` | 1,200 + fix-loop ref | fix-bug, fix-production-error | Triage table on entry (Asana bug / no ticket / production trace). Red test first. Same tail as implement. Incident path halts feature work; structural causes become a follow-up story, never a refactor under pressure. |
| `scope-guard` | 500 + audit-method ref (shrunk) | scope-guard | Accepts injected story + diff + plan record. Standalone-invocable. BEYOND/MISSING lists and fail-closed rule unchanged. Design Approach surface removed. |
| `setup` | 1,500 + components ref + scripts (merge-settings, detect-toolchain, render-assets, render-companion, render-pr-auto-review) + assets | init, setup-project, capability-preflight, pr-auto-review (install docs ≤1,000) | One transaction: engines present (six declared dependencies, one `claude plugin list --json`) → working agreement + design standard into CLAUDE.md via claude-md-management → settings merge → pre-push hook → CI guardrail → optional pr-auto-review. The auto-commit exception lives here and nowhere else. |
| `ui` | 800 + recipes as references (web-defaults + 3 recipes) | ui-creation, recipes | Accepts injected story/phase. Delegates to frontend-design. Resolution order stated once. |
| `hasura` | 3,000 + scripts/templates unchanged | hasura | Convention preamble cut to one statement; conventions persisted per repo in `.raftkit/hasura.json`. |
| `docs` | 800 + scripts (audit-docs.mjs, validate-docs.mjs) | docs (verify/sync half) | Parity check only: change set in, one of three exact strings out. Discovery result reused within the run. |
| `commands/help.md` | 300 | help | |
| **moved** | | docs (design/init/audit/scaffold, 29 templates, 12-phase flow) → `plugins/raftkit-docs` | Opt-in plugin, moved as-is, not on any hot path. Decision below. |
| **dropped** | | ultrathink, recipes (as a skill), pr (as a skill), simplify (as a skill), init, capability-preflight, pr-auto-review (as a skill), fix-production-error | Load-bearing content lands where the table says. ultrathink's playbook is a SHA-pinned snapshot of an external source: confirm its owner before deletion (decision below). |

### raftkit-qa (10.5k → ~4.5k words)

| v2 skill | Budget | Built from | Notes |
|---|---|---|---|
| `suite` | 1,200 + sheet-format ref | test-suite | Conflicts as one approve-all-with-exceptions prompt. |
| `run-sheet` | 900 + format ref | test-run-sheet | Validate (story has ACs?) before any fetch; suite lookup lazy; no stop. |
| `bug` | 1,300 + jam-evidence ref + filing-rules ref | file-bug, retest | Modes file / retest. Five judgment fields pre-proposed. Template once per chat. Retest validates build + checklist before fetching. |
| `commands/help.md` | 300 | help | |

## The working agreement (≤300 words, installs into a client CLAUDE.md)

> **RaftLabs working agreement for AI-assisted delivery**
>
> 1. **Right-size the model.** Haiku for renames, moves, fixtures, log parsing. Sonnet for components, tests, single-file refactors, ordinary debugging. The strongest model for cross-layer design and distributed-state bugs. A skill sets the model for each subagent it dispatches, reviewers on Sonnet by default, and reports the run's token total. The session model is the developer's choice; nobody is prompted to switch mid-run.
> 2. **Small phases.** Work is split into phases that compile and test in isolation, at most two files each. A subagent whose brief turns out larger returns a scope-reduction request to the parent, which re-splits.
> 3. **Plan visible before code.** The plan (scope from the story's ACs, phases with files and tier, tests) is written to `docs/specs/<branch>.md` and shown in chat before code starts. It is a record, not a stop; the developer interrupts if it is wrong.
> 4. **Green baseline first.** Build and typecheck run before the first edit. Red means fix the baseline before touching feature code.
> 5. **Tests from ACs.** Each acceptance criterion becomes a failing test before its implementation.
> 6. **Verify after.** Simplify, then lint, the full suite and one parallel review pass (design, silent failures, tests, security, scope, docs) run before a PR is drafted. Findings are fixed or answered in the PR description.
> 7. **No runaway loops.** A subagent that fails to fix the same error three times stops and reports; the developer decides.
> 8. **One stop.** The only mandatory approval in a run is before something leaves the session: a PR opened, an Asana or Sheet write, a message sent. Merge is always human.
> 9. **Incidents first.** A production trace (Sentry, CloudWatch, Crashlytics) halts feature work: reproduce as a failing test, fix, verify, prepare the PR. Structural causes become a follow-up story. Ask for recent logs before calling a deployment stable. Never deploy from a session.
> 10. **Session hygiene.** One session per feature. Run `/context` when a session feels slow.

For Ashit, what changed and why: the three blocking strings (`❌ ORCHESTRATION REJECTED`, `⚠️ EFFICIENCY WARNING`, `⚠️ SUBAGENT LOOP WARNING`) and the `📊 Session Health Check` nudge become behaviour (rules 3, 1, 7, 10) instead of stops; the spec-file gate becomes a plan record; the per-phase model prompt becomes skill-set tiers; the two-file threshold is kept at Ashit's value (pending decision 1216550892331152 is untouched); protocol 2.3 (scope reduction) and 5.1 (ask for logs) are kept explicitly.

## Test and CI strategy

- **Delete the 15 pure prose-pin suites**: asana-formatting, brainstorm, deprecation-sweep, design-approach, design-standard, docs-product, enablement-gaps, implement-clarification, profile-home, review-seams, story-gap-rule, ultrathink, user-story-amend, user-story-sizing, workflow-integration. Patching 491 greps costs more than reauthoring.
- **Keep the behavioural halves** **(panel)** of remediation (render-assets.mjs hostile manifest, validate-docs.mjs path escape), baseline-setup (render-companion.mjs), deterministic-rules (mds-eslint config), docs-scripts, capability-preflight (drop with classify.mjs unless setup keeps it), estimation-feature-list (the totals script over shipped examples).
- **Keep as is**: validate.test.sh, init-settings, telemetry (re-point its 5 prose greps), pr-auto-review-loop-guard, pr-auto-review-render, setup-toolchain + fixtures, hasura + nested suite, ci-blocking, plain-language PL6/PL7 + fixtures, scripts/check-plain-language.mjs (Gate-N rule removed), check-estimate-totals.mjs, scripts/validate.sh.
- **Add `tests/structure.test.sh`**: frontmatter valid and `name` matches directory; description ≤ 60 words; per-skill and per-plugin budgets from `tests/budgets.json` (+10%); at most one `**STOP**` line per SKILL.md and zero in skills that write nothing; GIDs appear only in `raftkit-core/skills/rules`; boilerplate appears once repo-wide ("Plain English out", "silence is not approval", the free-tier list, the live-fetch paragraph); no `## Reference files` or `## Asana rendering` sections; no `.mjs` invocation in pm or qa SKILL.md; the working agreement's sha256 matches the pinned value; every `refusals.json` pattern matches a string that exists in some skill.
- **Rewrite plain-language.test.sh**: drop PL1-PL5 and PL10; keep the checker over `plugins/` and the fixture arm.
- **Add an opt-in live-template smoke test** (`RUN_NETWORK_TESTS=1`, same pattern as the existing network suite): read the two template GIDs and assert the readiness derivation still parses. Run it nightly once a scheduled workflow exists.
- **Evals become the regression net.** Prune the 127 cases to surviving behaviours; add cases for one-stop implement (including `--plan-only`), batched bug ask, story author/amend with a NOT READY gap, estimate watermark; run `claude plugin eval` per plugin locally before and after each migration PR, results committed under `evals/results/`. Bump `CLAUDE_CLI_VERSION` in CI. Eval runs in CI wait on the API-key decision below.

## Migration order (one PR per step, each green on validate.sh + surviving suites, each bumping its plugin version and its help.md table in the same PR)

0. **Freeze v1.** Tag `v1-final` on `main`, branch `archive/v1`. Bump the CI CLI pin. Run `claude plugin eval` on all four plugins as-is; commit the baseline results.
1. **Core.** Add `rules` and `working-agreement`; rewrite `refusals.json`; add the new telemetry events; add `tests/structure.test.sh` (budgets scoped to new skills for now); rewrite plain-language.test.sh; delete the core prose-pin suites. The seven old core skills become 3-line pointers to `rules` **only while steps 2-5 are in flight on `development`** (so the not-yet-migrated role skills still resolve for anyone testing the branch); step 6 deletes them. Nothing old ships in v2.
2. **QA.** `suite`, `run-sheet`, `bug`. Smallest plugin, proves the one-stop pattern in Cowork.
3. **PM.** `profile`, `story`, `estimate`, `status`, `meeting`, `routine`. Drop story-skill-generator.
4. **Dev part 1.** `setup` (absorbs init, setup-project, capability-preflight, pr-auto-review install), `scope-guard`, `docs` (parity only); move the docs product to `plugins/raftkit-docs`.
5. **Dev part 2.** `implement`, `fix`, `ui`, `hasura` trim. Drop ultrathink, recipes, pr, simplify, fix-production-error.
6. **Close.** Delete the temporary core pointers. README (new skill names, a "renamed in v2" table), this repo's CLAUDE.md (plan-approval gate goes, one-stop rule comes in), `.claude/skills/story-driver` (documents the old gates and builds RaftKit itself), marketplace descriptions, eval prune + rerun against the baseline.

Steps 1-5 squash-merge to `development`; one release to `main` at the end so installed users see v2 as one update, after Ashit has cleared the working agreement. Old skill names do not survive the release: `/implement` stays (same name), `/user-story` becomes `/story`, `/file-bug` and `/retest` become `/bug`, and so on per the inventory tables. Each v2 skill's description carries the old trigger phrases so natural-language invocation still routes.

## Verification

- `bash scripts/validate.sh` and every surviving `tests/*.test.sh` green in CI on each PR.
- `tests/structure.test.sh` proves the budgets: total words under `plugins/raftkit-{core,pm,dev,qa}` ≤ 32k; every SKILL.md ≤ 500 words; one STOP per writing skill, zero per non-writing skill; GIDs only in core.
- `claude plugin eval` per plugin: no surviving case scores below its baseline; the new one-stop cases pass.
- Manual walk of the three journeys on a sandbox Asana project: `/implement` on one ready story reaches a PR draft with exactly one STOP and the phase table shown with live status; `/story` authors one story with one STOP and one template fetch (count connector calls); `/bug` files one Jam-backed bug with one STOP and no follow-up questions.
- Telemetry: `gate_shown`/`go`/`edit`/`abandon` events appear in the spool for each walk.
- Working agreement reviewed by Ashit before the release to `main`.

## What shipped (16 Sep 2026)

All seven steps are done on `feature/raftkit-v2`, eight commits, every suite green.

| | v1 | v2 |
|---|---|---|
| Skills installed by default | 35 | 18 |
| Instruction words installed by default | 187,000 | 24,158 |
| Plugins | 4 | 4 + 1 opt-in (`raftkit-docs`) |
| Test suites | 31 (70% prose pins) | 15 (behavioural + one structural) |
| Suites failing at rest | 3 | 0 |

Per plugin: core 3,713 words in 2 skills; pm 5,602 in 6; dev 11,893 in 7; qa 2,950 in 3; the opt-in docs product 22,196 in 2.

Commits, oldest first:

1. `docs:` the design and the CI CLI pin at 2.1.273.
2. `test:` grader frontmatter on all 127 eval cases, so `claude plugin eval` can load them.
3. `feat(core)!:` `rules` + `working-agreement` replace seven skills; telemetry records the stop as `raftkit_gate_shown`, flags the reply with `after_gate`, and carries `legacy_name` across the rename; `tests/structure.test.sh` + `tests/budgets.json` replace the core prose pins.
4. `feat(qa)!:` `suite`, `run-sheet`, `bug`.
5. `fix(qa):` the three-lens review findings (retest never closes a bug, `Done when` blocks the go until confirmed, one bug per retest run, refusals fenced so the checker and `refusals.json` see them).
6. `feat(pm)!:` `profile`, `story`, `estimate`, `status`, `meeting`, `routine`; `story-skill-generator` retired.
7. `feat(dev)!:` part 1 — `setup` absorbs init, setup-project, capability-preflight and the pr-auto-review installer; `docs` becomes parity-only; the design product and `discovery-interview` move to `raftkit-docs`.
8. `feat(dev)!:` part 2 — `implement` absorbs pr, simplify and ultrathink's plan step; `fix` absorbs both bug skills; `ui` absorbs recipes; hasura's preamble moves to a reference. Also fixes a real flake in the CI gate's own suite: past ~1000 loose objects git packs in the background after a commit and the fixture clone raced that repack.
9. `chore:` core pointers deleted, evals realigned, strict budgets, CLAUDE.md, README with a rename table, and the repo-local `story-driver` skill moved onto the one-stop model.

Two things behave differently from the plan as written, both deliberate:

- **The pre-push hook lost its spec gate** along with the spec-file gate, so `render-assets.mjs` dropped its two spec tokens. The hook still runs the repo's own quality scripts.
- **`raftkit-docs` depends on `raftkit-dev`** rather than duplicating the two docs scripts, which stay in `raftkit-dev:docs` where the parity check needs them.

**Known limitation: the eval harness does not yet load the skill under test.** All 83 prompts lacked frontmatter, so the runner granted zero tools and removed the Skill tool; every case scored zero no matter how good the skill was. Prompts now declare `allowed_tools`, each case sits with the plugin that owns its skill (enforced by PL12), and a `tool_used` grader asserts the skill fired. That grader passes for the estimate case, so the mechanism works — but a path target still does not resolve the skill for every case, and the documented `plugins:` hint changed nothing when tested. The 69 graders also still describe v1 wording. Until both are settled, an eval score is not a quality signal.

Still to do, and they are yours: push the branch, open the PR, get Ashit's sign-off on the working agreement before the release to `main`, and decide whether the eval runs move into CI.

## Decisions taken (16 Sep 2026)

1. **docs product (37k words):** moves to an opt-in `raftkit-docs` plugin as-is. Not installed by default.
2. **Old skill names:** clean break at the v2 release. No redirect stubs ship; README carries a rename table; descriptions carry old trigger phrases.
3. **Evals:** run locally with `claude plugin eval` before each merge; results committed. No API key in CI for now.

## Still open (do not block the build)

4. **ultrathink playbook:** the 12k-word snapshot is SHA-pinned as an external read-only source; confirm its owner agrees to retire it with the skill before step 5 deletes it.
5. **Telemetry dashboard:** skill renames split historical series; the `legacy_name` map in the skill event mitigates but the dashboard must read it.
6. **Ashit's sign-off** on the working agreement text gates the release to `main`, not the work on `development`.
