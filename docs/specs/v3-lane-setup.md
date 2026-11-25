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
