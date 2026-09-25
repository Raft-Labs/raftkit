# feat/raftkit-v2-1 — outcome per token

## Why

v2 (17 Sep 2026) cut RaftKit to 18 skills and one stop per run. The 23 Sep audit found it had never run where the work happens, its measurement broken end to end, and runs that failed late or wrote wrong things. v2.1 applies the approved roadmap to the repo; Asana was read, never written, as Aravind instructed.

## Scope contract

In scope: the roadmap items below, each held to its acceptance criteria. Everything else is out.

| Phase (branch `v21/…`) | Roadmap items | Files | Tests |
|---|---|---|---|
| g1-core-hooks | 0.1 client side, 0.2, 0.3, 1.1(b) entry map, 1.10 shunt, D1 telemetry scope | `raftkit-core/hooks/**`, README Telemetry | `telemetry`, `shunt` |
| g2-dev-flow | 1.1(a), 1.2, 1.3, 1.4 fix/docs, 1.8 PR body, 1.9, 1.11, 2.1 briefs, 2.2, the 2.4 and 2.5 call sites, 0.2's STOP total | `raftkit-dev` implement, fix, scope-guard, docs, `agents/verifier.md` | `dev-flow` (new), `docs-scripts` |
| g3-pm-qa-rules | 1.1(a)(c)(d)(e), 1.4 retest, 1.5, 1.6, 1.7 pm, 1.8 pm, 2.1 rules | `raftkit-pm/**`, `raftkit-qa/**`, core `rules`, five `help.md` | `cowork-telemetry`, `estimate-totals` |
| g4-setup-deps | 1.1(a), 1.12 engine list, 2.3, 2.4, 2.5, 2.8 | `raftkit-dev` setup, ui, `scripts/verify.mjs`, `plugin.json` | `init-settings`, `setup-toolchain`, `verify` (new), `pr-auto-review-render` |
| g5-hasura | 1.1(a), 1.10 hasura | `raftkit-dev/skills/hasura/**` | `hasura` |
| g6-docs-plugin | 1.7 docs, 2.9 | `raftkit-docs/**` | `companion-render` |
| a1-repo-docs | 1.2's opusplan record, 1.12 CLAUDE.md and design doc, 2.1's CLAUDE.md step 2, 2.4's principle 11, the groups' leftovers | CLAUDE.md, README, `docs/specs/`, two `help.md`, setup `components.md`, `refusals.json`, qa `bug` | `telemetry`, `dev-flow` DF17 |
| a2-story-driver | 1.12's story-driver part | `.claude/skills/story-driver/**` | its eval, every suite |
| a3-budgets | 2.6 | `tests/structure.test.sh`, `tests/budgets.json` | `structure` S4t, S5t, S16t, S18–S20 |
| a4-evals | 2.7 | `plugins/*/evals/**`, `tests/plain-language.test.sh` | `plain-language` PL12–PL17 |
| final review | what three reviewers found on the merged branch | `verify.mjs`, implement, fix, core hooks and rules, docs help, story-driver references, repo docs | `verify` V24–V25, `dev-flow` DF18–DF21, `telemetry`, `shunt`, `structure` S10 |

Phase tiers were not recorded for these workflow agents. g8-admin applied 0.1's server side in `raftkit-admin` on `fix/v2-gate-severity` (six local commits, unpushed); it is not part of this branch. Stages a1 to a4 branched from `2f9d51b` in parallel and merged at `ceb3351`: a2 applied 1.12's story-driver part, a3 applied 2.6 and a4 applied 2.7. A final review pass then fixed what three reviewers found on the merged branch.

Out, by decision: TypeSafe Jev in the product (3.3); Asana writes, including step 2's story drafts; the sandbox benchmark 0.4, which needs an Asana sandbox; edits to `working-agreement.md`; org-admin settings; Wave 3 (3.1 beyond the opt-in duplicate-review line, and 3.2).

## Decisions

Final. Jev broke each open tie at the confidence shown; the last two were split, so the rules decided.

| Decision | Ruling | Jev |
|---|---|---|
| Squash target | Read from the repo's own docs; none stops implement and fix in turn 1 | 1.00 |
| security-guidance | Default unchanged; setup offers only the opt-in `SG_PUSH_SWEEP=0` fix for duplicate reviews | 1.00 |
| Telemetry free text | Kept only in sessions where a RaftKit skill ran | 0.99 |
| Permission allow rules | Opt-in; local git (fetch, switch, add, commit) and detected gate scripts only | 0.86 |
| Routing | SessionStart entry map plus the five `help.md` routers | 0.81 |
| frontend-design | Loaded only when the story has no designs (and the Profile sets no visual system) | 0.81 |
| CI pr-auto-review | Keeps the full review on every run | 0.73 full review |
| Template reads | As rules do: fetched once, reused within the conversation while quotable verbatim; CLAUDE.md aligned | 0.47, split; rules decided |
| Sheets | Estimate re-run creates a new dated Sheet; suite re-sync shows changed rows | 0.25, split; rules decided |

As built, a suite re-sync writes nothing and so has no STOP (rules); its changed rows come back as CSV where the stop would be.

## Not done, or done differently

- **1.12 AC "no file names the old board GID":** met in the final pass. CLAUDE.md keeps the board's history without the GID, and the frontmatter fixture names the live board.
- **2.8:** there is no skip for a SHA `implement` already reviewed, and no named CI model. Both follow the full-review decision; a named model needs an owner call.
- **2.4 semver ranges:** skipped. Upstream has no `<plugin>--v<version>` tags, so a range would fail the install.
- **0.1 AC4, the "help reports it" half:** the stuck-delivery line shows at session start, at most once a day, and core help says so.
- **0.1 server side:** v2.1 events reach the server deployed today: `flush.mjs` sends severity `gate` as `info`, which admin `main` accepts, and the final pass made clamped text storable (no NUL, no lone surrogate). Admin `main` still rejects a whole batch for one invalid event, so `fix/v2-gate-severity` should be deployed before v2.1 merges to `main`, which the org install ships to every user. Its refusal mirror matches `refusals.json` at `1a2bf5f`: it lacks `squash-target-undocumented`, `write-tool-missing` and the typographic apostrophe.
- **2.6 AC3, runtime journey budgets:** not built; a bench journey needs the 0.4 sandbox.
- **2.7 AC3, baseline results:** none committed. Three cases tagged `needs-live-template` allow no Asana tool, so a correct run stops at the template read and cannot pass as written.
- **1.1 AC4, trigger reach on a fresh profile:** unmeasured; it needs the 0.4 trigger prompts.
- **Working agreement sign-off:** on `main` since 17 Sep without Ashit's sign-off. CLAUDE.md still says it needs sign-off before the release to `main`; that line waits for the founders' decision and was not edited.
- **meeting's Profile delta comment:** 1.6 removed the comment from profile only. Whether meeting keeps its own is an owner call.
- **Still open:** the phase file limit decision (`1216550892331152`).

## Verification

- Every phase ran `bash scripts/validate.sh` and every `tests/*.test.sh` with telemetry on, green at its tip; all were green at the merged `2f9d51b`. Each new contract check was mutation-checked: mutated once, seen red, restored.
- 0.2: `run-tokens.mjs` came within 20% of the `~/.claude.json` ledger on real sessions (−4.5%, −4.2% and 0.0% on three, within 1.4% and 0.1% on two more).
- a1: the two refusal rules and DF17 were seen red before their change. They were mutation-checked seven ways: the backtick tolerance, the write-tool rule, and each source string through S14, plus DF17's fix side, retest side and bare prefix. validate.sh and all 20 suites pass at the stage tip.
- a1 to a4: suites green at the merge, `ceb3351`.
- Final review pass: each finding verified before it was fixed (parallel commits in one checkout, parallel fetches and the pipe truncation reproduced in scratch repos; the duplicate ledger id shown by a two-session check; jsonb's refusals and in-insert dedup checked on PGlite). Every new check was seen red first or mutation-checked, and validate.sh and all 20 suites pass at its tip.
- Not verifiable here: the plan's estimated figures (they need 0.4) and the admin half until it is deployed.
