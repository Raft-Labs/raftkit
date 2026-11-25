# v3/lane-setup — setup and opt-in split

Source: `docs/specs/2026-11-25-raftkit-v3-thinning-proposal.md` (stories 2, 13, 14) plus the D2 engine drop in setup. A record, not a gate.

## Scope contract

In scope:

1. **Story 2 — `feat(setup): pre-push reuses the verify cache`.** The rendered hook reads `<git common dir>/raftkit/verify.json`, keys on the tree of each pushed sha (pre-push stdin), and skips the gates only when every pushed tree has a green entry for every gate in `QUALITY_SCRIPTS`, with the command `<PM> run <gate>`, under one hour old. Anything else runs the full gates as today. No `${CLAUDE_PLUGIN_ROOT}`, no `--no-verify`, the hook never writes the cache.
2. **D2 in setup — drop superpowers from the engine checks.** No setup file lists it; `check-engines.mjs` keeps deriving engines from raftkit-dev's `plugin.json`.
3. **Story 13 — `chore(setup): retire pr-auto-review` (D3).** Delete the fix-loop prompt, workflow, renderer, reference, tests and evals; setup offers an opt-in review-only CI snippet (≤40 lines, comment-only, never commits, never merges). CLAUDE.md's non-negotiable loses its exception sentence.
4. **Story 14 — `chore: opt-in split` (D4).** (a) Hasura moves to a new `plugins/raftkit-hasura` (1.0.0, depends on raftkit-core), behaviour identical. (b) raftkit-docs: docs-product cut to ~3k words (SKILL.md + references), 8 templates kept plus the companion's `claude-md.md`, discovery-interview folded in as one ~400-word reference.

Out of scope: everything else — `verify.mjs`, `tests/budgets.json`, `tests/structure.test.sh`, every `commands/help.md`, raftkit-dev's `plugin.json`, other lanes' skills and tests.

## Phases

| # | Story | Files | Tests |
|---|---|---|---|
| 1 | Pre-push cache | `setup/assets/pre-push`, `setup/references/components.md`, `tests/setup-toolchain.test.sh` | P1–P10 in `setup-toolchain.test.sh`, red first |
| 2 | Drop superpowers | `setup/SKILL.md`, `tests/setup-toolchain.test.sh` | E4b (no setup file names superpowers) |
| 3 | Retire pr-auto-review | `setup/assets/{fix-loop-prompt.md,pr-auto-review.yml}` (deleted), `setup/assets/review-only.yml` (new), `setup/scripts/render-pr-auto-review.mjs`, `setup/references/{pr-auto-review,components}.md`, `setup/SKILL.md`, `evals/pr-auto-review/`, `tests/pr-auto-review-*.test.sh`, `tests/setup-toolchain.test.sh`, `CLAUDE.md`, `README.md` | R1–R4 in `setup-toolchain.test.sh`, red first |
| 4 | Hasura plugin | `plugins/raftkit-hasura/**` (moved), `.claude-plugin/marketplace.json`, `setup/references/components.md`, `tests/hasura.test.sh`, `CLAUDE.md`, `README.md` | `hasura.test.sh` with new paths, HR15 on the new manifest |
| 5 | Thin raftkit-docs | `plugins/raftkit-docs/**` except `commands/`, `.claude-plugin/marketplace.json`, `tests/companion-render.test.sh`, `CLAUDE.md`, `README.md` | `companion-render.test.sh` C1–C14 |

## Integration notes

### Story 2 — pre-push cache

- `tests/verify.test.sh` V18 ("the pre-push hook still runs every approved gate itself, with no cache") fails by design: the hook now reads `verify.json`. Replace V18 with "the hook reads the cache and still names `__QUALITY_SCRIPTS__`", or delete it; P1–P11 in `tests/setup-toolchain.test.sh` cover the behaviour. Also drop "The pre-push hook keeps running its gates in full." from the header comment of `tests/verify.test.sh` (line 6).
- `plugins/raftkit-dev/scripts/verify.mjs` lines 10–11 still say "The pre-push hook does not use this script and keeps its full gates." Proposal story 2 asks for that stale comment to be fixed: replace with "The pre-push hook reads this cache (green only, same commands, under an hour) and runs its gates in full on any miss." Not edited here: verify.mjs is outside this lane.
- Cache contract the hook now depends on: `<git common dir>/raftkit/verify.json`, an array of `{ tree, results: { <role>: { command: "<pm> run <role>", at: ISO } } }`, reuse window 1 h (`REUSE_MS`). Any change to that shape or window in verify.mjs must change `setup/assets/pre-push` in the same diff.
- Budget: `raftkit-dev/setup` total grows by ~45 words (components.md, one paragraph).

### Drop superpowers from setup

- Engines stay derived from `plugins/raftkit-dev/.claude-plugin/plugin.json` (`check-engines.mjs` E4, `merge-settings.mjs` managed `enabledPlugins`). superpowers leaves the engine check the moment the dev lane (proposal story 5) drops it from that manifest; nothing in setup hardcodes it. E15 now pins that no setup file, eval or toolchain fixture names it.
- `tests/init-settings.test.sh` O10 now uses `security-guidance@claude-plugins-official` as the never-disabled engine, so it keeps passing after superpowers leaves `plugin.json`.
- Outside this lane, still naming superpowers as an engine example: `plugins/raftkit-core/hooks/lib/refusals.json` `missing-engine` example (change to `Missing: pr-review-toolkit. Install it with: claude plugin install pr-review-toolkit@claude-plugins-official`, which setup's SKILL.md now emits); `plugins/raftkit-dev/evals/plain-language/setup-missing-engine/prompt.md` line 7. `README.md`'s quick-start install line is updated here to three engines.

### Story 13 — retire pr-auto-review (D3)

- `tests/budgets.json` `files`: remove the `plugins/raftkit-dev/skills/setup/assets/fix-loop-prompt.md` entry (2520 words / 3910 tokens); structure S18 fails on it until then. The new `assets/review-only.yml` is YAML, not markdown, so it needs no `files` entry.
- `raftkit-dev/setup` total drops by the deleted `references/pr-auto-review.md`; the raftkit-dev plugin word/token totals drop by it and by `fix-loop-prompt.md`. Re-measure after merge.
- `tests/telemetry.test.sh` line ~702, "CLAUDE.md's non-negotiable names exactly one exception", fails by design: invert it to `! grep -qiE 'exactly one exception|pr-auto-review' <<<"$gates"` ("CLAUDE.md's never-auto rule has no exception"). The next check ("blocker telemetry is not an exception") still passes.
- Deleted suites: `tests/pr-auto-review-loop-guard.test.sh`, `tests/pr-auto-review-render.test.sh`. Drop them from any suite list or CI matrix that names them.
- `plugins/raftkit-dev/commands/help.md`: the `setup` row says "optional PR auto-review" → "optional review-only CI"; the rename line's `pr-auto-review → setup` is history and can stay.
- `README.md` line 67 (v1→v2 rename table, `pr-auto-review` → `raftkit-dev:setup`) is history and stays.
- Before release (D3): check installed client repos for `.github/workflows/pr-auto-review.yml`; setup no longer owns that file, so a re-run reports it as foreign rather than updating it.
