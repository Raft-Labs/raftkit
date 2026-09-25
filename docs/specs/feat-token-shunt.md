# feat/token-shunt — bulk-read shunt and measured run tokens

## Why

Spotify's Portal post ([engineering.atspotify.com, Sep 2026](https://engineering.atspotify.com/2026/9/portal-by-spotify-cut-my-claude-code-token-usage-by-90)) reports ~90% fewer tokens by routing non-reasoning work to cheap models, enforced by `PreToolUse` hooks rather than by asking the model nicely.

RaftKit already holds the policy half of that idea and none of the enforcement half:

- working-agreement rule 1 "Right-size the model", `implement/SKILL.md:15` per-phase `tier:`, reviewers on Sonnet — all prose.
- `rules/SKILL.md:29` "subagents inherit nothing" and rule 2's two-file phase cap are stronger context isolation than Portal's ephemeral invocations.
- Every hook is telemetry. Nothing intercepts a 3,000-line read.
- No token or cost data is recorded anywhere, so no saving — Portal's or ours — can be proved.

## Scope

In: measured run tokens; a `bulk-reader` subagent; a `PreToolUse` shunt; the tier vocabulary; a mutation-proven test suite.

Out: Portal's `code-writer` (a cheap model writing to disk unreviewed collides with rules 5 and 6 — Portal excludes editing for the same class of reason); any external model or service (routing client source to a third-party processor is a DPA decision for the founders, not a config change); pinning a model in `pr-auto-review.yml`; the stale board GID in `CLAUDE.md`.

## Phases

| # | Tier | Files | Tests |
|---|---|---|---|
| 1 | standard | `hooks/lib/tokens.mjs`, `hooks/record.mjs` | `tests/shunt.test.sh` §8 |
| 2 | standard | `hooks/lib/shunt-rules.mjs`, `hooks/shunt.mjs`, `hooks/hooks.json`, `agents/bulk-reader.md` | `tests/shunt.test.sh` §1–7, 9 |
| 3 | mechanical | `skills/working-agreement/references/tiers.md`, `commands/help.md`, manifests, `tests/budgets.json` | `tests/structure.test.sh`, `scripts/validate.sh` |

## Decisions

- **Worker is Haiku, in-session.** A subagent definition carries its own model, so Portal's "declarative mode" is native here. No service, no third-party processor, client source stays on Anthropic.
- **The deny message is the instruction.** Portal needs a companion skill because its alternative is a bash wrapper; ours is one `Agent(...)` call, so no skill is added and no word budget moves.
- **The invariant holds.** `hooks.json` promised every hook exits 0 so it can never break a session. A `PreToolUse` veto is `permissionDecision` on stdout with status 0 — a decision the session handles, not a failure. Verified against the installed CLI (2.1.274).
- **Threshold 500 lines**, `RAFTKIT_SHUNT_MIN_LINES` to move it, `RAFTKIT_SHUNT=off` to disable. A junk or zero override falls back to the default rather than shunting everything.
- **Instructions are never shunted.** `CLAUDE.md`, any `SKILL.md`, anything under `skills/`, plan records, the agreement, `budgets.json`. A paraphrased scope contract is the failure `rules/SKILL.md:58` exists to prevent. Matched on path segments, never substrings.
- **Subagents are not policed** (amended v2.1). The hook runs inside subagent tool calls too, and a subagent's reads land in its own context, never the session's. Any payload carrying `agent_id`, which Claude Code sets only inside a subagent, is exempt; so is the bulk-reader by its plugin-scoped name `raftkit-core:bulk-reader` under `claude --agent`. The v1 exemption matched the bare `bulk-reader`, a name plugin agents never report, so it denied the bulk-reader its own reads. The agent still pages every read with `offset`/`limit`, the deny text still names that route, and the agent has no `Agent` tool, so it cannot recurse. It sets `omitClaudeMd: true`.
- **Fail open everywhere else.** Missing file, unreadable file, binary, directory, symlink out of the repo, unparsable payload.
- **Read only** (amended v2.1). The Bash matcher and its `cat`/`head`/`tail`/`sed` parser are removed: a Bash result over Claude Code's output cap is truncated anyway, so the shunt could never deny one, yet it spawned node on every Bash call (about 31 ms each).
- **Tokens carried on the stop event, not spooled separately.** The spool is a capped buffer; a second line per turn would evict real `raftkit_blocked` events. This departs from the approved plan, which named a `raftkit_run_tokens` event.

## Verification

Full suite 16/16 green (baseline was 15/15 green on `development`, including the two suites a stale handoff listed as env-flaky). `scripts/validate.sh` passes. Lint: 0 errors, 5 pre-existing warnings; `buildEvent` was already over the line limit at 85 lines / complexity 33 and is now 87 / 34.

Mutation pass: 24 mutations, 23 caught. The one escape is the top-level `try/catch` around `main()` — unreachable by construction, because every inner path already fails open, so it is a maintenance guard rather than untested logic. It is kept deliberately: `await main()` without it would reject and exit non-zero before `process.exit(0)` runs. The harness restores from a pre-run baseline and the tree is diffed against it afterwards; an earlier run aborted mid-way and left a mutation in the working tree, which the suite caught on the next run.

## Follow-ups (not in this diff)

- `tests/structure.test.sh` S16 counts only `plugins/*/skills/**/*.md`. `agents/*.md` is instruction the model reads and is now outside the budget regime.
- `implement/SKILL.md:15` names a phase's `tier` but has ~16 words of headroom, so it does not point at `tiers.md`.
- `pr-auto-review.yml` pins no model and inherits `claude-code-action`'s default.
