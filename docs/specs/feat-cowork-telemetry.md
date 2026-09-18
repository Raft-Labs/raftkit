# feat/cowork-telemetry — the one line that reports a skill in Cowork

## Why

Telemetry sees Claude Code only. The hooks under `raftkit-core/hooks/` build events and POST them to the admin API, but a Cowork session runs in a sandbox with no host filesystem and no hooks, so `record.mjs` and `flush.mjs` never execute. PM and QA work — the whole reason `raftkit-pm` and `raftkit-qa` exist — is invisible.

Cowork has a first-party OpenTelemetry export instead, which an admin turns on once and which reports prompts, tool failures and errors with no help from any skill. What it does not report is **skills**: Cowork emits no event when a skill runs, because a skill is expanded internally as a prompt ([claude-code#41845](https://github.com/anthropics/claude-code/issues/41845), closed as not planned). The only trace a skill leaves is what it says.

The receiver half, `Raft-Labs/raftkit-admin#3`, **merged on 26 Aug** with a migration and a dashboard tile. The plugin half never shipped, so that tile has been empty ever since. This is the missing half.

## Why this is a rebuild and not a rebase

PR #62 forked at `34bd708` on 21 Aug, before the v2 refactor collapsed 35 skills into 18. Of its 23 files, **21 conflict** — 16 as modify/delete, where git stages the file as deleted-by-them and the one-line addition is silently dropped rather than flagged. The 5 genuinely shared files were rewritten wholesale by the v2 commit.

So the branch was reset onto `main` and the content re-applied. PR #62 keeps its number, its thread, its review history and its author; only the diff is rebuilt.

## Scope

In: the contract skill; the announcement line on the 9 surviving pm/qa skills; the disclosure corrections in `README.md`, `rules` and core `help.md`; the CW suite; three version bumps.

Out: the frontmatter fix that shared the source branch (shipped separately as #65 — folding it in would have made this a four-plugin PR and cost the changelog line its meaning); any second reporting path; any change to the Claude Code hook path.

## What changed against the pre-v2 original

| | Pre-v2 | Here |
|---|---|---|
| Skill body | 1012 words | 810 |
| Description | 82 words | 50, and colon-space free for #65's guard |
| Bullet on each skill | 35 words | 12 |
| Skills carrying it | 12 | 9 |
| Cross-references | `house-rules`, `write-protocol` | `rules` (write-protocol has no v2 successor) |
| Canonical example | `raftkit-pm:brainstorm` (dropped in v2) | `raftkit-pm:story` |

## Decisions

- **The 35-word bullet could not ship.** Measured S4 headroom was 5 words on `qa/bug`, 15 on `pm/routine`, 29 on `pm/story`. The 12-word form fits all nine and reads like v2 prose. None of the nine has a `Guardrails` section any more, so the original insertion point was gone; CW4 and CW5 grep the whole file, so position is style and the bullet closes the body.
- **The `Plain English out` bullet had to go.** S8 fails any skill but `raftkit-core/rules` for carrying that literal, and v2 inherits the rule rather than restating it.
- **The "not a write" boundary points at the rule instead of repeating it.** The original restated the draft → approve → push gate and linked a skill v2 deleted. It now says what mechanically happens and defers to `raftkit-core:rules`, keeping the literal `It does not write anything` that CW6 pins.
- **Three budget raises, all reviewer-visible.** `raftkit-core` 4500 → 5000 (the cap was set when core had two skills; it now has three), `raftkit-core/rules` `skill_md` 640 → 700 (the Cowork paragraph leaves 6 words of headroom otherwise), and the eight pm/qa entries at 500 → 520. `estimate` sits at 570 and absorbs the bullet unchanged.
- **Version ladder.** core `1.1.1 → 1.2.0`, pm and qa `1.0.1 → 1.1.0`, all clearing the versions #65 left behind.

## Verification

`tests/cowork-telemetry.test.sh` — CW0-CW10. Three checks were repaired rather than re-globbed:

- **CW6 was a no-op.** It ran `! grep -q cowork-telemetry .../write-protocol/SKILL.md` against a path v2 deleted; grep exits 2, `!` inverts it, the check passed unconditionally. It now extracts the `## One stop per run` section body and asserts the exception is absent from it.
- **CW2** pinned an example skill that no longer exists.
- **CW7/CW8** pinned strings in a file that no longer exists.

**CW0** is the general fix: every file the suite reads is asserted to exist before any check runs, so a later deletion fails by name instead of quietly turning `! grep` into a pass.

Mutation-tested, **10 mutations, 0 escapes** — including the two shapes the original could not catch: an exception smuggled into the one-stop section, and the skill file deleted outright.

## Open, and not resolved here

`plugins/raftkit-core/hooks/lib/skill-aliases.json` maps v2 names to v1 so the Claude Code hook path keeps dashboard series continuous. The Cowork path has no such mapping — the announcement emits the **v2** name (`Using raftkit-pm:story`) and the merged receiver captures whatever it matches. Unless `raftkit-admin` applies the same alias map on ingest, Cowork rows land under `story` while Claude Code rows land under `user-story`, and one skill splits into two series. The receiver's `refusals.json` is also diverged — 117 lines there against 85 here.

This is live-data correctness rather than a gate, and it is the most likely way for the feature to look broken after it ships. It needs someone to check the merged receiver.
