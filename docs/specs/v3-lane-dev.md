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
- `tokens.mjs` reports gain a `weighted` field (cost-weighted input-token equivalents); telemetry stop events carry it inside `tokens` (additive).
- implement and fix STOPs now quote `run-tokens.mjs ${CLAUDE_SESSION_ID} --stages`; DF9 still matches.

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
