# v3/lane-core — remove the shunt, lean core

Source: `docs/specs/2026-11-25-raftkit-v3-thinning-proposal.md`, stories 3 and the core half of 15.

## Scope contract

In scope:

- **Story 3 — `chore(core): remove the Read shunt, bulk-reader and the entry-map nag`.** Delete `hooks/shunt.mjs`, `hooks/lib/shunt-rules.mjs`, the `PreToolUse` Read entry in `hooks.json`, the `raftkit_shunt` event, `agents/bulk-reader.md` and the entry map's NOT_SET_UP line. The entry map itself stays: it still routes plain-language requests to `raftkit-dev`. `tests/shunt.test.sh` is deleted; its token-accounting sections (§8, §8b) move verbatim into `tests/telemetry.test.sh`. `tiers.md` loses the bulk-reader paragraph; the `hooks.json` description loses the shunt.
- **Story 15, core half — `chore(core): lean core`.**
  - `rules/SKILL.md` to ~450 words, every cross-role invariant kept; "New skills", the long Telemetry section and "subagents inherit nothing" deleted; one-stop bullets gain "the write response is the read-back when it returns the rendered body" and "an edit re-presents only the changed sections".
  - `readiness.md` ~300 words (6 gap types, `PASS —` and `NOT READY —` strings byte-identical), `asana-html.md` ~250–400, `asana-calls.md` ~90.
  - `plain-language.md` leaves the runtime path → `docs/maintainers/plain-language.md`.
  - `cowork-telemetry` skill → `docs/maintainers/cowork-telemetry.md`.
  - One core help (~150 words) routes by role; the pm, dev, qa and docs `help.md` routers and their "Renamed in v2" tables are deleted.
  - `skill-aliases.json` content untouched (it holds no shunt or bulk-reader entry).

Gating: story 15 is gated on D5 (release bar for `main`); the help's `raftkit-qa:test-cases` route is gated on the QA owner decision (proposal story 12).

Out of scope: everything else — evals, budgets, structure suite, README, marketplace, manifests' versions and descriptions, working-agreement text, `tokens.mjs`, `refusals.json`, role skills.

## Phases

| # | Story | Tier | Files | Tests |
|---|---|---|---|---|
| 1 | 3 | standard | `raftkit-core/hooks/{shunt.mjs,lib/shunt-rules.mjs,hooks.json,entry-map.mjs}`, `raftkit-core/agents/bulk-reader.md`, `working-agreement/references/tiers.md`, `raftkit-core/commands/help.md` | `telemetry.test.sh` §14 (no nag), §15 (shunt gone), §16 (token accounting, moved); `shunt.test.sh` deleted |
| 2 | 15 | mechanical | `rules/SKILL.md`, `rules/references/*`, `skills/cowork-telemetry/` → `docs/maintainers/cowork-telemetry.md`, `plain-language.md` → `docs/maintainers/`, `scripts/check-plain-language.mjs`, five `commands/help.md` | `cowork-telemetry.test.sh`, `plain-language.test.sh`, `telemetry.test.sh` |

## Tests

Test first for the hooks: §14 and §15 of `telemetry.test.sh` fail before the deletion. The markdown is held by the existing suites, re-pointed first: `cowork-telemetry.test.sh` reads the maintainer doc, `plain-language.test.sh` reads the moved reference.

## Integration notes

Budgets (`tests/budgets.json`, owned by integration):

- `raftkit-core/rules`: `skill_md` 589 words / 908 tokens (was 700 / 1,130); `total` (SKILL.md + 3 references) 1,301 words / 1,926 tokens (was 2,200 / 3,300).
- Delete the `raftkit-core/cowork-telemetry` skill entry (S1 fails until then). It is now `docs/maintainers/cowork-telemetry.md`.
- `files`: `plugins/raftkit-core/commands/help.md` → 148 words / 291 tokens (was 490 / 790). Delete the pm, dev, qa and docs `commands/help.md` entries (S18–S20 fail until then).
- `plugins.raftkit-core` drops by roughly 1,700 words (rules −470, references −900, cowork-telemetry −784); lower it and `plugin_tokens` to the measured size.

Structure and other suites:

- `tests/validate.test.sh` check 6 adds its undocumented-skill fixture under `raftkit-qa`, which no longer has a `help.md`, so `scripts/validate.sh` skips it and the check fails. Move the fixture to `plugins/raftkit-core/skills/`: core help is now the only help with a skills table, and lists `rules` and `working-agreement`.
- `tests/shunt.test.sh` is deleted. Its §8 (token accounting) and §8b (`run-tokens.mjs`) moved verbatim into `tests/telemetry.test.sh` §16, under their own `TOK_ROOT`. If lane dev's story 1 changed `run-tokens.mjs` output or edited `shunt.test.sh`, port that change into §16.
- `tests/telemetry.test.sh` showed flush/stuck-delivery failures once under parallel machine load (stub-server timing); two re-runs passed with no change.

Manifests, README and docs (not this lane's files):

- `plugins/raftkit-core/.claude-plugin/plugin.json` and its `.claude-plugin/marketplace.json` entry still say "the bulk-read shunt with its bulk-reader subagent". Change both, in one edit, since telemetry.test.sh and `validate.sh` require them equal: `RaftKit rules (Asana constants, the one human stop per run, fetch-once live reads, Asana HTML, free tier, scope line, escalation, readiness, plain output), the RaftLabs working agreement and Module Design Standard, and usage and token telemetry hooks.`
- Version bumps: raftkit-core, raftkit-pm, raftkit-dev, raftkit-qa and raftkit-docs all changed (the last four lost `commands/help.md`).
- `README.md`: line 108 lists "when the read shunt declines a file, its extension and line count" — remove; lines 45–52 list five `/raftkit-*:help` commands — only `/raftkit-core:help` remains; line 56 says core "added `cowork-telemetry`" — it is a maintainer doc now; line 94 troubleshoots `/raftkit-dev:help` — point at `/raftkit-core:help`.
- `skill-aliases.json` has no shunt or bulk-reader entry; nothing removed. The core help routes to the v3 names `raftkit-qa:test-cases` and `raftkit-hasura:hasura`; those exist only once the qa and opt-in lanes land.
- The entry map keeps "raftkit-dev:fix (it runs systematic-debugging itself)", the counter-routing the critique (I9) asks to keep while superpowers is installed. Drop that parenthetical when story 5 (D2) removes superpowers.
- `rules` now reads "the Profile sections the run uses" (was "read all"), matching the proposal's step 1 intake. The Telemetry section is one line; its rationale is `docs/maintainers/cowork-telemetry.md`.
