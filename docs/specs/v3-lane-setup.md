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

### Story 14a — Hasura becomes `raftkit-hasura` (D4)

- `tests/budgets.json` `skills`: rename the key `raftkit-dev/hasura` → `raftkit-hasura/hasura`, numbers unchanged (skill_md 500 / 970 tokens, total 4000 / 7390 tokens, writes true, v2 true). Measured after the move: SKILL.md 546 words, plugin 3869 words / 7390 tokens.
- `tests/budgets.json` `plugins` / `plugin_tokens`: add `"raftkit-hasura": 4000` and `"raftkit-hasura": 7400`. `raftkit-dev` loses the Hasura skill (≈3870 words / 7390 tokens); re-measure it after all lanes merge.
- `tests/structure.test.sh`: S15's strict loop (`for d in plugins/raftkit-core/skills/*/ ... raftkit-qa/skills/*/`) and S16's plugin list (`raftkit-core raftkit-pm raftkit-dev raftkit-qa raftkit-docs`) must add `raftkit-hasura`.
- `plugins/raftkit-dev/.claude-plugin/plugin.json` description still says "Hasura migrations"; drop it (e.g. "Developer skills: repo setup, story implementation, bug and incident fixes, scope audit, UI, and docs parity — one stop per run.") and set the same string on the `raftkit-dev` entry in `.claude-plugin/marketplace.json` in the same edit. This lane left the marketplace entry unchanged so `scripts/validate.sh`'s lockstep check, `setup-toolchain.test.sh` S43 and the old HR15 stay green. Bump raftkit-dev's version for the removal.
- `plugins/raftkit-dev/commands/help.md`: the description's "Hasura migrations → raftkit-dev:hasura" and the `hasura` table row must go. Until they do, `scripts/validate.sh` fails ("table references nonexistent skill(s): hasura"), so `tests/validate.test.sh` "valid repo passes" fails on this branch. A one-line pointer to `raftkit-hasura:hasura` belongs in whichever help survives story 15.
- `plugins/raftkit-core/hooks/lib/skill-aliases.json`: the `//` note lists hasura among skills that kept their name; telemetry now reports it with `skill_plugin` = `raftkit-hasura`, so that series splits at release, as discovery-interview's did.
- `CLAUDE.md` first line still says "one repo shipping five plugins"; it is now six (outside this lane's two CLAUDE.md edits).
- raftkit-hasura depends on raftkit-core only. Its SKILL.md still hands schema docs to `raftkit-dev:docs` and names `raftkit-dev:setup` for activation; both stay valid while raftkit-dev is installed for every developer.
- Org-sync default (D4): the admin removes raftkit-docs from the org-sync set and does not add raftkit-hasura. README now states that split.

### Story 14b — raftkit-docs thinned (D4)

- No pm, qa or dev skill loads `discovery-interview` (grep of `plugins/raftkit-{pm,qa,dev,hasura}` is empty). It is folded into `docs-product/references/interview.md` (~420 words) and the skill directory is deleted.
- docs-product now: SKILL.md 711 words / 1313 tokens; SKILL.md + references 2929 words / 4867 tokens. References: `design-flow.md`, `interview.md`, `generation.md`, `existing-docs.md`, `scaffolding.md`, `story-adapter.md`, `bug-adapter.md` (the last two unchanged). Deleted: `stack-and-domain-recipes.md`, `stack-anti-patterns.md`, and the eight references merged into the four new ones.
- Templates kept (9): readme, claude-md (the companion's CLAUDE.md template), architecture-overview, module, feature, api-rest, schema-dbml, adr, test-plan. Deleted (20): api-appsync, api-graphql-hasura, api-orpc, api-webhook-incoming, api-webhook-outgoing, async-job, changelog, changes-log, compliance-pii, decisions, design-guidelines, glossary, nfr, observability, rbac-matrix, schema-drizzle, schema-hasura, state-machine, tech-stack, workflow. The companion asset and its renderer are untouched.
- `tests/budgets.json` `skills`: delete `raftkit-docs/discovery-interview`. Set `raftkit-docs/docs-product` to skill_md 720 / skill_md_tokens 1320, total 3000 / total_tokens 4900, and drop `as_is` (it is rewritten, so the shape checks now apply; its description is 52 words).
- `tests/budgets.json` `plugins` / `plugin_tokens`: `raftkit-docs` 38110 → 9000 words, 64800 → 15300 tokens (measured 8913 / 15246; templates count here).
- `tests/structure.test.sh` S1 fails on `raftkit-dev/hasura` and `raftkit-docs/discovery-interview` until those budget keys change (story 14a note and above); S18/S19 fail on the `fix-loop-prompt.md` entry (story 13 note). Those five are the only structure failures on this branch.
- `plugins/raftkit-docs/commands/help.md` (outside this lane): drop the `discovery-interview` table row and the description's last sentence ("discovery-interview is the design flow's own interview contract, never run alone."); change "29 adaptable templates" to "9 adaptable templates". `scripts/validate.sh` fails on that row (after the `hasura` row in raftkit-dev's help). Verified on a scratch copy: with both rows removed, `scripts/validate.sh` passes.
- `plugins/raftkit-core/hooks/lib/skill-aliases.json` `//` note mentions discovery-interview's earlier move; the skill is now gone, so its telemetry series ends.
- raftkit-docs version 1.1.0 → 2.0.0 (a skill removed); marketplace description in lockstep.
- `README.md` "Renamed in v2" section ("plus 2 in `raftkit-docs`") is history and stays.
