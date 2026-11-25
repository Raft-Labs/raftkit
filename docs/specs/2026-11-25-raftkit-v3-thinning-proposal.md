# RaftKit v3: thinning proposal

Status: proposal for founders and the kit owner. Nothing here is built.
Basis: a read-only audit of `main` @ 785913b. Five parallel audits, three competing designs, one judge panel and one adversarial critique.

> **Every time and token figure in this document is an estimate built from reading the skills. None is a measurement.** Story 1 replaces them with measured numbers before anything is cut.

## 1. Diagnosis: where the 1–2 hours go

We walked one reference run of `raftkit-dev:implement`:

- **Story:** 13 files, FE + BE, 6 `[AC]`s, in a pnpm/turbo TS monorepo.
- **Estimated cost before the STOP:** 77–143 min, 1.5–3M billed tokens.
- **Scale:** 14–17 subagents, plus about 11 background security-guidance reviews.

| # | Time sink | Where | Est. cost |
|---|---|---|---|
| 1 | **2-file phases, each a cold worktree subagent.** 13 files become 7–8 phases. Every phase re-reads the codebase from scratch, re-installs or re-resolves `node_modules`, loads the superpowers TDD skill, then gets cherry-picked back. FE→BE dependencies allow only 4–5 parallel waves. | working-agreement rule 2; `implement/SKILL.md:24` | 35–60 min |
| 2 | **Serial review tail.** Simplifier, then a full suite run, then 4 toolkit reviewers plus the verifier. The verifier itself runs scope-guard, then docs, then lint + typecheck + suite, then triage, fix and an improvised re-verify. | `implement/references/review.md`, `agents/verifier.md` | 30–55 min |
| 3 | **Repeated gates.** About 12 typechecks, 4 full suite runs, 3 lint runs and 3 `git fetch`es per story. | intake, simplify, verifier, pre-push | 20–40 min, mostly on the critical path |
| 4 | **Planning exploration that no phase reuses.** Phase briefs carry two file names, not the parent's codebase map. | `implement/SKILL.md:23–24` | 6–14 min |
| 5 | **Intake and readiness.** A full Project Profile read, plus readiness re-derived after PM already checked it. | `rules/SKILL.md:19`, `readiness.md` | 4–10 min |
| 6 | **Pre-push after the go.** Every gate re-runs uncached. | `setup/assets/pre-push` | 4–12 min |

The full diff is read by an LLM about 7 times per run, and the codebase is explored about 14 times.

**Root cause.** v2 was designed for 200k-context models that drifted on long tasks, so it isolated every two files in a fresh agent and added a reviewer per failure mode. Current models hold a 13-file story in one context. Claude Code now ships natively the pieces RaftKit rebuilt by orchestration:

- plan mode;
- `/code-review` with effort levels;
- `/simplify`;
- `/security-review`;
- worktrees;
- plugin dependencies;
- `claude plugin eval` and `/usage`.

Anthropic's current guidance also advises against "use a subagent to verify"-style scaffolding.

**What is genuinely RaftLabs and must stay:**

- the Asana story as the contract;
- each `[AC]` becomes a failing test first;
- `Do NOT build:` as a hard line;
- one STOP before anything leaves the session;
- never merge and never tick `[AC]`/`Testing`;
- GIDs in one place;
- free tier only;
- the founder watermark.

## 2. Thesis: four gates, each run once

Keep the house contract and delete the scaffolding. A defect or scope creep is caught by exactly four gates, each placed where it can actually catch something:

1. **Red-first per `[AC]`.** The test is committed before its implementation, and that order is checkable in git history.
2. **One independent spec-aware review** of the final diff. It runs in a separate context and carries the `[AC]`s, the `Do NOT build:` line and the plan table. It also performs the hunk-level scope judgment (BEYOND / MISSING).
3. **Deterministic scripts:**
   - `verify.mjs` runs lint, typecheck and the suite;
   - a new `scope-check.mjs` is a pre-filter: unplanned files, `[AC]`s with no test, and plan rows added after the plan was shown;
   - `validate-docs.mjs`.
4. **One authoritative full verify** on the final tree, reused by pre-push.

security-guidance keeps running in the background. Everything else goes: phase subagents, per-phase worktrees, cherry-picks, the verifier wrapper, the serial simplifier, the 5-way fan-out, and repeated fetches and typechecks.

## 3. The new implement run

Same 13-file reference story. Ranges below are the critic's realistic figures, not the optimistic design numbers.

| # | Step | What happens | Est. min |
|---|---|---|---|
| 0 | Load | `implement` (~900 words), with STOP, scope and never-merge in its first lines. Core rules (~400 words). | <1 |
| 1 | Intake, one parallel turn | All in one turn:<br>• the story, every `[AC]` verbatim and the `Do NOT build:` line<br>• the live Feature Template<br>• only the Profile sections a dev run uses<br>• squash target and branch convention<br>• one `git fetch` and a pinned `base-sha`<br>• a background baseline typecheck (plus build where it is a separate compile) | 2–4 |
| 2 | Readiness | The full 6-gap check against the live template. It is skipped only when the story carries a readiness PASS newer than its last edit. | 0.5–1 |
| 3 | Plan, in the main thread, shown and not gated | Explore once. Write `docs/specs/<branch>.md`: a table with one row per `[AC]` (AC verbatim, test file, source files), the `Do NOT build:` line, and a 300–500-word codebase map. Hash the table. | 4–8 |
| 4 | Build, in the main thread | Per `[AC]` slice:<br>• write the failing test, run it, commit `test:`<br>• implement to green<br>• run targeted tests and the package typecheck<br>• commit<br><br>Three strikes on the same error stops the run. A subagent pair is used only when the plan marks FE and BE as independent behind a frozen contract; that path keeps the merge-base check and the cherry-pick. | 25–40 |
| 5 | Inline simplify | The parent checks its own diff against the design standard. One separate commit, so it reverts cleanly. | 1–3 |
| 6 | Gate batch, one turn, in parallel | All at once:<br>• re-fetch the `[AC]`s and diff them against the plan table<br>• one reviewer (spec + correctness + silent failures + scope, hunk-level)<br>• full `verify.mjs`<br>• `scope-check.mjs`<br>• `validate-docs.mjs` | 5–10 |
| 7 | Triage and fix once | Each finding is fixed in one commit or answered in the PR. BEYOND clears only by a human sign-off by name. | 0–8 |
| 8 | Final verify | A cache hit if step 7 committed nothing. | 0–8 |
| 9 | STOP | PR title + 6-section description (section 4 generated from the plan table), the Asana comment, the Development tick, and the run-tokens line. Unchanged contract. | 1–2 |
| 10 | On go | Push. Pre-push reuses the cache when the pushed tree matches and the cache is under 1 h old; otherwise the full gates run. Never merge. | ~0.1–12 |

**Typical result:** about 50–65 min before the STOP, against an estimated 110 min today. That is roughly a 45–50% cut. A clean story with no findings lands nearer 40 min. Subagents per run drop from 14–17 to 1–3.

The `fix` skill follows the same flow, with the bug's `Done when` as the contract and an inlined 4-line debugging method. Estimate: 15–30 min.

> **Honest limit.** The remaining time is mostly real work: writing the code, red/green runs, a monorepo typecheck. Going much below ~40 min for a 13-file story would mean cutting a gate, and this proposal does not.

## 4. The kit, before and after

| | v2.1 today | v3 |
|---|---|---|
| Default plugins | 5 (all via org sync) | 4 (core, pm, dev, qa); raftkit-docs and Hasura become opt-in |
| Third-party dependencies | 4 (superpowers, pr-review-toolkit, security-guidance, frontend-design) | 1 required (security-guidance); frontend-design optional |
| RaftKit agents | 2 (verifier, bulk-reader) | 1 spec-aware reviewer, or `/code-review` |
| Subagents per implement run | 14–17 | 1–3 |
| Hot-path words loaded | ~3,700 + ~4,500 toolkit prompts + a TDD skill load per phase | ~2,300 |
| Core rules + references | 2,257 words | ~1,000 |
| Help routers | 5 (2,296 words) | 1 (~150) |
| PM / QA skills | 6 / 3 | 5 (routine deleted; size folds into estimate) / 2 (test-cases replaces suite + run-sheet; bug) |
| Hooks | Read shunt + bulk-reader, entry-map nag, telemetry | Telemetry only; shunt and nag removed |
| Evals | 79 cases, 313 files, never scored | ~12 policy cases + 1 trigger case per skill, scored against a no-plugin baseline with mocks |
| Gate runs per story | suite 4, typecheck ~12, fetch 3 | suite 1–2, typecheck ~6–9, fetch 1 |

## 5. Guarantees kept, and what enforces each

| Guarantee | Enforced by |
|---|---|
| Story = spec; every `[AC]` has a test | `scope-check.mjs` MISSING, plus the reviewer's "each test asserts its AC" lens |
| `Do NOT build:` is a hard line | Reviewer judges hunk by hunk in an independent context. `scope-check` pre-filters. Only a named human clears BEYOND. |
| Red before green (rule 5) | A `test:` commit precedes the implementation commit per `[AC]`; `scope-check` reads git order |
| Green baseline (rule 4) | `verify.mjs --only typecheck` exit code at intake |
| `[AC]`s current at audit | Re-fetch in the gate batch, diffed against the plan table |
| One authoritative gate | `verify.mjs` on the final tree; pre-push cache keyed on the pushed tree, with the same script set |
| One STOP; refusal strings byte-identical | Core rules; structure suite S6/S14; telemetry parses the STOP |
| Never merge or tick `[AC]`/`Testing` | Core rules plus a policy eval. Hardening via a `gh pr merge` deny rule goes to the board as a separate proposal. |
| Live templates, GIDs in one place, free tier, founder watermark | Unchanged |

## 6. Working with Claude, ChatGPT/Codex and others

Facts checked against vendor docs in Nov 2026:

- **SKILL.md is an open standard (Agent Skills)**, now under the Linux Foundation's Agentic AI Foundation.
  - Codex CLI and ChatGPT, Cursor, Gemini CLI and GitHub Copilot all read `.agents/skills`.
  - Condition: frontmatter limited to the spec fields (`name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`). RaftKit's `user-invocable` key would be a hard error outside Claude Code.
- **AGENTS.md is read by Codex, Cursor, Copilot, Gemini and others.** Claude Code reads it through a `CLAUDE.md` containing `@AGENTS.md`.
- **The Asana spine is the portability limit.** Codex reaches Asana only through `mcp-remote`, which Asana does not support.

What follows from that:

| Part of the kit | Portable? |
|---|---|
| The working agreement and the methodology, moved into the client's `AGENTS.md` | Yes, to every agent |
| PM and QA skills | Portable wherever an Asana connector exists (Claude, Cowork, ChatGPT) |
| Dev runs on client code | Claude-only until the founders decide whether client code may go to non-Claude agents (D6) |

This proposal makes the format portable: spec-only frontmatter and skill-relative script paths. It does **not** ship a cross-vendor bundle. That bundle is a board proposal gated on D6.

## 7. Decisions needed

| # | Decision | Owner | Blocks | If declined |
|---|---|---|---|---|
| D1 | **Working-agreement text edits, folded into the sign-off already pending before any `main` release:**<br>• Rule 2: keep the two-file value if wanted, but drop "subagent" (phases build in the main thread). Better: phases become `[AC]` slices — open decision `1216550892331152`.<br>• Rule 4: "typecheck, plus build where it is a separate compile".<br>• Rule 6: one inline simplify + one review + scripts.<br>• Rule 7: three strikes, whoever builds.<br>Re-pin the sha. | Ashit | Stories 6, 7 | Sequential phase subagents without worktrees (the existing fallback). This saves about 25–35 min instead of 45–60. |
| D2 | Retire "orchestrate, rebuild nothing" in favour of "native first, orchestrate what native lacks". Drop superpowers now (its SessionStart injection pushes brainstorming and plan gates into the main thread). Drop pr-review-toolkit once the spec-aware reviewer is proven. | Founders | Stories 6, 10 | Interim reviewer stays `pr-review-toolkit:code-reviewer`. |
| D3 | Retire the pr-auto-review auto-commit exception in favour of review-only CI. Check installed client repos first. | Founders | Story 13 | Keep it, but move it to an opt-in plugin. |
| D4 | Move raftkit-docs and Hasura out of the org-sync default. | Founders | Story 14 | They stay installed for everyone. |
| D5 | Release bar for `main`, since org install auto-updates everyone. | Founders | Stories 9, 15 | — |
| D6 | Vendor scope: may client code go to Codex, Cursor or Copilot? | Founders (contract and relationship risk) | Cross-vendor bundle | Dev stays Claude-only; PM/QA formats stay portable. |
| — | Owner decisions: meeting folds into profile; test-cases replaces suite + run-sheet. Verify Sheets append and Asana tagging in Cowork first. | PM / QA owners | Stories 11, 12 | Fallbacks are stated in those stories |

The scheduled-routine unattended-write decision stays pending. `routine` is deleted, and its meeting-notes prompt does not ship.

## 8. Migration: one story = one PR, in order

**Release 1: hot path.** Target ≥35% wall-clock cut with no change in `[AC]` or scope outcomes.

1. `chore(dev): measure the v2.1 baseline`
   - `run-tokens.mjs` prints per-stage minutes, with cache-read tokens reported separately from cost-weighted tokens. (Raw "billed" tokens would rise with a main-thread build and mis-score the change.)
   - Replay 3 reference stories (13-file FE+BE, small, fix) from a pinned `base-sha` on a scratch branch.
   - Decline at the STOP, so nothing is written. Two runs per story.
2. `feat(setup): pre-push reuses the verify cache`, test first
   - A cache lookup is rendered into the hook, keyed on the pushed tree and running the same `QUALITY_SCRIPTS`.
   - Falls back to the full run.
   - Fix the stale comment at `verify.mjs:10-11`.
3. `chore(core): remove the Read shunt, bulk-reader and the entry-map nag`.
4. `feat(dev): scope-check.mjs and the plan-record AC table`, test first
   - Fixtures for each case: unplanned file, `[AC]` with no test, plan row added after the hash, test commit after its implementation.
5. `chore(dev): drop the superpowers dependency` (D2)
   - Inline the TDD and debugging method in about 5 lines each.
6. `feat(dev): one-pass review tail` (D1, D2)
   - Delete `agents/verifier.md`. `review.md` becomes the gate-batch spec.
   - The reviewer brief carries the `[AC]`s, the `Do NOT build:` line and the plan table, and returns scope-guard's exact block.
7. `feat(dev): implement builds in the main thread by [AC] slice` (D1)
   - One-turn intake, codebase map, red-first commits, an FE/BE pair path with the cherry-pick kept.
   - Lower budgets.
8. `feat(dev): thin fix` — same flow, with `Done when` as the contract.
9. `chore(dev): pilot` on one client repo, replaying story 1's scenarios.
   - Done when: ≥35% faster, identical `[AC]` and scope outcomes, no policy eval regression, and a fixed reference review of each diff is no worse.
10. `release: RaftKit 2.2 hot path` (D5)

**Release 2: deletion only.**

11. `feat(pm): consolidate`
    - size folds into estimate; delete routine; meeting folds into profile.
    - Cut status, story and the PM routers.
12. `feat(qa): consolidate` — test-cases is keyed on `[AC]` GID; trim bug.
13. `chore(setup): retire pr-auto-review` (D3)
    - Remove the fix-loop prompt, workflow, renderer, tests and evals.
    - Offer a review-only CI snippet.
14. `chore: opt-in split` (D4)
    - Hasura becomes its own plugin.
    - docs-product is cut to about 3k words, with discovery-interview folded in.
15. `chore(core+test): lean core and lean tests`
    - Rules down to about 400 common words; one help command.
    - Evals reset to about 12 policy cases plus trigger cases, run against a no-plugin baseline with mocks. Informational in CI first.
    - One token budget per skill; prose pins deleted; suites run in parallel.
    - Release.

**Board proposals, not in this scope:**

- AGENTS.md relocation of the governance pack;
- the `.agents/skills` export (D6);
- the `gh pr merge` deny rule;
- per-stage dashboards.

## 9. Risks

- **Main-context growth on large stories.** Mitigations:
  - critical rules sit in the first lines of the skill;
  - the plan record is the resume point after compaction;
  - stories over roughly 25 files are split at the PM stage. A new refusal string goes into `refusals.json` in the same diff.
- **Mid-phase edits from security-guidance.** Its async rewakes now land in the main thread mid-phase. Non-Critical ones defer to step 7.
- **Lost model tiering.** Mechanical edits run on the session model. This is accepted: it is cheaper than a cold subagent.
- **Org auto-update blast radius.** The pilot gates Release 1.
- **Unmeasured third-party cost.** superpowers and security-guidance were not installed on the audit machine, so their costs are unmeasured until story 1.
