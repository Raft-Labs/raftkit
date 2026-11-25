# v3/lane-dev — dev hot path (RaftKit v3 thinning, Release 1)

Spec: `docs/specs/2026-11-25-raftkit-v3-thinning-proposal.md` (§3, §8 Release 1, §7 D1). Branch from `main` @ 785913b.

## Scope contract

In scope, one commit each, in this order:

| # | Story | Commit |
|---|---|---|
| 1 | `run-tokens.mjs --stages`: per-stage wall-clock minutes (intake, plan, build, review, stop) and cache-read tokens apart from cost-weighted tokens; `Token total: not measured` fallback kept | `feat(dev): …` |
| 4 | `scripts/scope-check.mjs` and the plan-record `[AC]` table: unplanned files, `[AC]`s with no test in the diff, rows added after the plan hash, test commit not before its implementation; scope-guard takes an injected base-sha and judges hunk by hunk | `feat(dev): …` |
| 5 | Drop superpowers from raftkit-dev's dependencies; TDD and debugging method inlined where implement and fix need them | `chore(dev): …` |
| 6 | One-pass review tail: delete `agents/verifier.md`; `review.md` becomes the gate-batch spec; simplify inline; docs drops the verifier | `feat(dev): …` |
| 7 | implement builds in the main thread by `[AC]` slice; >25-file refusal added to `refusals.json` | `feat(dev): …` |
| 8 | Thin fix: same flow, `Done when` as the contract | `feat(dev): …` |
| D1 | Working agreement rules 1, 2, 4, 6, 7 (gated on D1) | `chore(core)!: …` |

Also: the stale pre-push comment in `scripts/verify.mjs`.

Out of scope: everything else — setup, pre-push hook, shunt/bulk-reader, help routers, budgets, structure suite, PM/QA/docs plugins, the eval reset, release.

## Phases

| Story | Files | Tests |
|---|---|---|
| 1 | `plugins/raftkit-core/hooks/lib/tokens.mjs`, `plugins/raftkit-dev/scripts/run-tokens.mjs`, implement/fix `SKILL.md` (STOP quotes `--stages`) | new `tests/run-tokens.test.sh` (red first); `shunt`, `telemetry`, `dev-flow` unchanged |
| 4 | `plugins/raftkit-dev/scripts/scope-check.mjs`, `skills/implement/references/plan.md`, `skills/scope-guard/SKILL.md`, `tests/fixtures/scope-check/` | new `tests/scope-check.test.sh` (red first), `dev-flow` |
| 5 | `.claude-plugin/plugin.json`, implement/fix `SKILL.md` | `dev-flow` (DF15, DF22) |
| 6 | `agents/verifier.md` (deleted), `implement/references/review.md`, `implement/references/simplify.md`, `skills/docs/SKILL.md` | `dev-flow` (DF5, DF11, DF19 rewritten) |
| 7 | `implement/SKILL.md`, `implement/references/pr.md`, `refusals.json` | `dev-flow` (DF12–DF14, DF18, DF23) |
| 8 | `fix/SKILL.md`, `fix/references/loop.md`, `evals/fix/pending-build-marker/prompt.md` | `dev-flow` (DF20, DF24) |
| D1 | `working-agreement.md` | `structure` S12 (re-pin) and S13 |

## Integration notes

Filled in per story below; the integration agent owns `tests/budgets.json` and `tests/structure.test.sh`.

### Story 1
- New suite `tests/run-tokens.test.sh` (fast, no network): add it to whatever lists the suites.
- `run-tokens.mjs` without `--stages` prints the byte-identical v2.1 line, so `tests/shunt.test.sh` §8/§8b stays green. If lane core deletes `shunt.test.sh` with the Read shunt (story 3), move its §8 token-accounting and §8b run-tokens cases into `tests/run-tokens.test.sh` rather than dropping them.
- `tokens.mjs` reports gain `list_usd` (the run's cost at each model's first-party list price) and `unpriced` (tokens on a model with no listed price); telemetry stop events carry both inside `tokens` (additive). The price table in `tokens.mjs` is dated 2026-11-03: a new model shows up as `unpriced` until a row is added.
- implement and fix STOPs now quote `run-tokens.mjs ${CLAUDE_SESSION_ID} --stages`; DF9 still matches.
- In-run, the STOP message is not written yet, so the `stop` stage stops at the run-tokens call. The story-1 baseline replay re-runs `run-tokens.mjs <session> --stages` after declining the STOP, as the script header says.

### Story 4
- New suite `tests/scope-check.test.sh` with fixtures in `tests/fixtures/scope-check/`; new script `plugins/raftkit-dev/scripts/scope-check.mjs` (exit 0 clean, 1 flags, 2 not checked).
- New reference `implement/references/plan.md` (the plan-record template) counts toward the implement `total` budget; final numbers are under "Budgets" below.
- `dev-flow` DF22 pins the plan template's table header and hash comment to what `scope-check.mjs` parses.

### Story 5
- `tests/init-settings.test.sh` O10 uses `superpowers@claude-plugins-official` as the example of an engine `merge-settings.mjs --disable-plugins` must refuse. `merge-settings.mjs` reads the engines from raftkit-dev's `plugin.json`, so superpowers is no longer one and O10 fails on this branch: swap the example for `security-guidance@claude-plugins-official`.
- Lane setup: drop superpowers from `setup/scripts/check-engines.mjs`, from the `Missing: superpowers …` example in `setup/SKILL.md` line 24, and from `evals/plain-language/setup-missing-engine/prompt.md` if it should list only current engines.
- `refusals.json` `capability-unavailable` example names superpowers; the pattern is engine-agnostic, so it still passes S14. Change the example to `security-guidance` when setup's line changes (that entry is not an addition, so this lane leaves it).
- `README.md` line 24 and `CLAUDE.md` line 3 name superpowers among raftkit-dev's declared dependencies: now three (security-guidance, pr-review-toolkit, frontend-design).

### Story 6
- `plugins/raftkit-dev/agents/verifier.md` is deleted, and with it `plugins/raftkit-dev/agents/`; `implement/references/simplify.md` is folded into `review.md` step 1 and deleted.
- `raftkit-core/skills/working-agreement/references/tiers.md` row `standard` still says "Reviewers, the simplifier and the Explore survey": the simplifier is now inline in the parent. Lane core: drop "the simplifier".
- `plugins/raftkit-dev/commands/help.md` lines 14 and 23 say "one parallel review pass" and "test-first phases": after stories 6–7 it is "inline simplify, one gate batch (one reviewer + verify, scope-check, docs scripts)" and "[AC] slices in the main thread".
- `tokens.mjs` `runStages` still recognises `raftkit-dev:verifier` as a review marker on purpose: it measures v2.1 transcripts for the baseline.
- `dev-flow` DF5, DF11 and DF19 are rewritten for one reviewer, the three gate scripts and the range pinned at intake.

### Story 7
- `refusals.json` gains `story-too-large` (source `raftkit-dev/skills/implement/SKILL.md`), placed ahead of `generic-cant`; S14 passes.
- Budget: implement's directory stays inside today's 1,600-word total; only `skill_md` words rise, offset by the deleted `simplify.md`, the verifier and a smaller `pr.md`. The pair path lives in `implement/references/pair.md`, read only when the plan marks FE and BE independent. Final numbers are under "Budgets" below.
- `raftkit-core:rules` "Fetch once" says to read the Project Profile and "read all" sections (Constants table). implement now reads only the stack, environments and conventions sections; lane core should let a role skill read the sections it uses.
- `raftkit-core:rules` "Fetch once" also says "Subagents inherit nothing: brief each with only the slice it uses". Still true on the pair path; no change needed.
- `dev-flow` DF5, DF12 and DF18 are rewritten for the main-thread build and the pair path; DF23 is new.

### Story 8
- `fix/references/loop.md` is deleted (rationale prose, read by nothing); its two live rules (a task binds in full, linked or not; separate repro and fix commits) are in `fix/SKILL.md`.
- `scope-check.mjs` accepts a `Done when` key column so fix's record is checked the same way (`tests/scope-check.test.sh` case K).
- `dev-flow` DF5 and DF14 drop fix's subagent; DF24 is new.
- `evals/fix/pending-build-marker/prompt.md` now states steps 2 and 3 ran in the session, not in a subagent.

### verify.mjs comment
- The header no longer claims the pre-push hook ignores the cache. `tests/verify.test.sh` V18 now pins only that the hook keeps `__QUALITY_SCRIPTS__` as its fallback, so lane setup's cache lookup in the hook does not break it; lane setup owns the test for the lookup itself.

### D1 (gated: do not release before Ashit's sign-off)
- Re-pin `working_agreement_sha256` in `tests/budgets.json` to `1db69ecfdcef78c823ee85cafc0392b73758fa4bcce1fefeb7b397e496a4eb30`. Until then `structure` S12 and `init-settings` (line ~313, which compares the installed block to the pinned sha) fail.
- Body is 310 words, exactly the S13 cap.
- `raftkit-core/skills/working-agreement/SKILL.md` line 18 says "The two-file limit in rule 2 is Ashit's value": rule 2 no longer states a number. Lane core: "Any per-phase file limit in rule 2 is the open phase-file-limit decision in this repo's CLAUDE.md." Its protocol map ("decomposition and scope reduction → 2") is still accurate enough.
- Repo `CLAUDE.md` "Open decisions" row: "Rule 2 of the working agreement ships two files as its value" → "Rule 2 leaves the per-phase file limit open; phases are [AC] slices built in the main thread".
- D1 sign-off item, not edited in this lane: rule 3 still says the plan shows "phases with files and tier", but builds are `[AC]` slices with no tier and `plan.md` has no tier column. Proposed for Ashit together with rules 2/4/6/7: "(scope from the acceptance criteria, phases with files and tier, tests)" → "(the acceptance criteria as scope, each with its test and files)", 11 words for 11, so the body stays at the 310-word S13 cap. Re-pin the sha again if it lands.

### Fix pass (lane review)
- `scope-check.mjs` reads the table as first committed for every check: a row widened, added or deleted after the plan is flagged `ADDED AFTER PLAN` (`changed —`, new, `removed —`), and its files stay BEYOND candidates / MISSING. Rows sharing a test file find their test commit by the `test: <the [AC]>` subject, else print `ORDER not checked: <ac> — shared test file` (not a flag). New `tests/scope-check.test.sh` cases L, M, N, O; case D now also expects the added row's files as BEYOND candidates.
- `review.md` gate batch: the `[AC]` re-fetch and `scope-check.mjs` run first; the reviewer is then briefed with the fetched `[AC]`s, the plan record path and the flags, in parallel with `verify.mjs` and `validate-docs.mjs`. The brief exempts the scope audit from the reviewer's confidence threshold, and an unmapped scope-check BEYOND candidate stays BEYOND. Simplify skips with no runnable suite and runs `verify.mjs --only test` before its commit. DF11 pins all of it; scope-guard names the injected `scope-check` output.
- `runStages` markers are version-stable (see the one-line comment in `tokens.mjs`): plan opens at exploration after the story reads, not at the branch; the simplifier and `scope-check.mjs --hash` open no stage; stop opens after the final verify. `tests/run-tokens.test.sh` adds a v3-ordered transcript.
- `evals/plain-language/setup-missing-engine/prompt.md` names only current engines (done here; lane setup need not).

## Budgets (for `tests/budgets.json`, measured at the branch tip)

| Key | Now | Budget today | Proposed |
|---|---|---|---|
| `raftkit-dev/implement` `skill_md` / `skill_md_tokens` | 700 w / 1,161 t | 600 / 1,100 | 700 / 1,100 (words only; tokens within headroom) |
| `raftkit-dev/implement` `total` / `total_tokens` | 1,599 w / 2,558 t | 1,600 / 2,790 | unchanged |
| `raftkit-dev/fix` `skill_md` / `skill_md_tokens` | 982 w / 1,487 t | 850 / 1,370 | 990 / 1,490 |
| `raftkit-dev/fix` `total` / `total_tokens` | 982 w / 1,487 t | 1,250 / 1,880 | 990 / 1,490 (lower) |
| `raftkit-dev/scope-guard` | 508 w / 784 t | 500 / 720 | unchanged (within headroom) |
| `raftkit-dev/docs` | 822 w total | 800 total | unchanged (within headroom) |
| `raftkit-dev` plugin words / tokens | 14,953 / 25,131 | 14,000 / 25,630 | unchanged (within headroom); lower after the merge if other lanes cut |

The implement hot path (SKILL + plan + review + pr) is 1,505 words against main's 1,759 for SKILL + review + simplify + pr, and the run no longer loads five toolkit reviewer prompts, the verifier or a superpowers skill per phase. fix's `skill_md` rise is offset by deleting `loop.md` (its total falls 260 words).

## Suites on this branch

All 22 pass except, as expected for the integrator: `structure` (S4 words for implement and fix, per the table above; S12 sha) and `init-settings` (O10 superpowers example, M3 sha).
