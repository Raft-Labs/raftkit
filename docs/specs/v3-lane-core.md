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

Out of scope: everything else — evals, budgets, structure suite, README, marketplace, manifests' versions and descriptions, working-agreement text, `tokens.mjs`, `refusals.json`, role skills.

## Phases

| # | Story | Tier | Files | Tests |
|---|---|---|---|---|
| 1 | 3 | standard | `raftkit-core/hooks/{shunt.mjs,lib/shunt-rules.mjs,hooks.json,entry-map.mjs}`, `raftkit-core/agents/bulk-reader.md`, `working-agreement/references/tiers.md`, `raftkit-core/commands/help.md` | `telemetry.test.sh` §14 (no nag), §15 (shunt gone), §16 (token accounting, moved); `shunt.test.sh` deleted |
| 2 | 15 | mechanical | `rules/SKILL.md`, `rules/references/*`, `skills/cowork-telemetry/` → `docs/maintainers/cowork-telemetry.md`, `plain-language.md` → `docs/maintainers/`, `scripts/check-plain-language.mjs`, five `commands/help.md` | `cowork-telemetry.test.sh`, `plain-language.test.sh`, `telemetry.test.sh` |

## Tests

Test first for the hooks: §14 and §15 of `telemetry.test.sh` fail before the deletion. The markdown is held by the existing suites, re-pointed first: `cowork-telemetry.test.sh` reads the maintainer doc, `plain-language.test.sh` reads the moved reference.

## Integration notes

Filled in as the lane runs; see the end of this file.
