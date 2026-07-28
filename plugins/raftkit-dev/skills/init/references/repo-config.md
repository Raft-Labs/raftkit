# Repo config — managed keys, merge rules, and the version marker

## Managed settings-key table

Every value here is copied from the maintainers' own working
`~/.claude/settings.json` — house policy, not invented for this skill. A repo
that changes house policy changes this table, not a per-repo override.

| Key | Managed value | Why |
|---|---|---|
| `extraKnownMarketplaces.raftkit` | `{ source: { source: "github", repo: "Raft-Labs/raftkit" }, autoUpdate: true }` | Replaces the hand-paste step the README documents today |
| `enabledPlugins` | `raftkit-core@raftkit`, `raftkit-dev@raftkit`, `superpowers@claude-plugins-official`, `code-simplifier@claude-plugins-official`, `claude-md-management@claude-plugins-official`, `security-guidance@claude-plugins-official`, `pr-review-toolkit@claude-plugins-official` — each `true` | These are the engines raftkit-dev's own skills call by name today (`implement`, `setup-project`); installed-but-disabled degrades the workflow silently |
| `model` | `"opusplan"` | House default |
| `attribution` | `{ "commit": "", "pr": "" }` | House default — no Claude attribution on commits or PRs; the current (non-deprecated) syntax |
| `permissions.allow` | `Bash(git status:*)`, `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(claude plugin list:*)`, `Bash(gh pr view:*)` | Read-only commands raftkit skills run constantly; without these a first run is a wall of prompts |

These land in the **committed** `.claude/settings.json` so the repo behaves
identically for whoever opens it — that is the point of `init`. Nothing here
ever touches `.claude/settings.local.json`.

## Merge and conflict rules — `scripts/merge-settings.mjs`

The script is the only write path; it is a pure function of
(existing file, the table above) → (new file | conflict report | parse error).

- **Object keys merge additively.** `extraKnownMarketplaces` and
  `enabledPlugins` keep every existing entry; only the managed sub-keys are
  added or checked.
- **`permissions.allow` is a union.** Existing rules are never removed;
  managed rules not already present are appended in the table's order, so an
  unchanged re-run produces byte-identical output.
- **A conflict is any existing value that differs from the managed one** —
  on a scalar (`model`), a nested pair (`attribution.commit` /
  `attribution.pr`), an object leaf (`extraKnownMarketplaces.raftkit`), or a
  managed plugin explicitly set to something other than `true`
  (`enabledPlugins["raftkit-core@raftkit"]: false` is a conflict, not a
  silent flip back to enabled). Conflicts are reported together, and
  **nothing is written** — exit code `2`.
- **Fail-closed on unreadable input.** A `.claude/settings.json` that fails to
  parse as JSON aborts with the parse reason on stderr and writes nothing —
  exit code `1`. The renderer never guesses at malformed input.
- **Identical inputs produce byte-identical output** — an unchanged re-run
  reports `no changes` and does not rewrite the file (exit code `0`).

This same conflict-detection path serves both the first-run case (an existing
foreign value on a managed key) and the re-run drift case (someone hand-edited
a managed key since the last `init`) — one mechanism, not two.

## The version marker

`.raftkit/init.json` — tracked, alongside `setup-project`'s own
`.raftkit/governance-pack.json`:

```json
{
  "init_version": "<raftkit-dev version at init time>",
  "installed_at": "<ISO date>",
  "managed_keys": [
    "extraKnownMarketplaces.raftkit",
    "enabledPlugins",
    "model",
    "attribution",
    "permissions.allow"
  ],
  "capability_check": "capability-preflight"
}
```

`init_version` is the installed **raftkit-dev** version, so a repo initialized
under one version is comparable against a later one on re-run, the same way
the pack marker compares against raftkit-core.
