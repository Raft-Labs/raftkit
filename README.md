# raftkit

RaftLabs' private Claude plugin marketplace — the RaftLabs way of shipping software, installable with one command. Internal — RaftLabs only.

## Prerequisites

- Membership in the RaftLabs GitHub org, with git auth working locally (`gh auth login` or SSH keys).
- Claude Code **v2.1.143 or later** — check with `claude --version`, upgrade with `claude update`. Older versions install plugins without their dependencies.

## Quick start

Add the marketplace (takes under a minute):

```bash
claude plugin marketplace add Raft-Labs/raftkit
```

Marketplace added — now install your role plugin: raftkit-pm, raftkit-dev, or raftkit-qa.

```bash
claude plugin install raftkit-dev@raftkit   # or raftkit-pm / raftkit-qa
```

Installing any role plugin automatically installs `raftkit-core` alongside it. Inside a Claude Code session, the same commands work as `/plugin marketplace add` and `/plugin install`. Verify with `claude plugin list` — you should see your role plugin and `raftkit-core`.

## Plugins

| Plugin | Who | What |
| --- | --- | --- |
| `raftkit-core` | everyone (auto-installed) | House rules, workflow constants, governance protocols |
| `raftkit-pm` | PMs | Onboarding, user stories, story readiness, status updates, meeting decisions, estimation |
| `raftkit-dev` | Developers | Init, implement, scope guard, simplify, PR, bug fix, UI creation, project setup, recipes |
| `raftkit-qa` | QA | Test suites, test run sheets, bug filing, retest |

v1 ships exactly these four plugins. PM and QA plugins target the Claude apps/Cowork runtime; the install path there is pending the org-wide install decision (Asana task 1216551001583573) — until it lands, use Claude Code with the commands above.

## Getting help

Every plugin ships a help command — run it inside a Claude Code session:

```
/raftkit-pm:help        # PM workflow: profiles, stories, readiness, updates
/raftkit-dev:help       # Dev workflow: implement → PR, bugs, setup
/raftkit-qa:help        # QA workflow: suites, run sheets, bugs, retest
/raftkit-core:help      # Shared rules, constants, governance protocols
```

Pass a skill name or question for a focused answer, e.g. `/raftkit-dev:help scope-guard` or `/raftkit-pm:help how do I onboard a project`.

## Updates

New versions arrive automatically via Claude Code's plugin refresh, or on demand:

```bash
claude plugin marketplace update raftkit
```

No need to re-add the marketplace. Installs resolve to the latest stable version; there is no pre-release channel in v1.

## Troubleshooting

**Permission denied / repository not found when adding the marketplace:**
You need access to the RaftLabs GitHub org — ask in #raftkit.

**Stuck install:** installs normally finish in under a minute. If one hangs or times out ("Git clone timed out"), your git auth is usually the cause — run `gh auth status` and re-authenticate. On slow connections, raise the timeout: `export CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS=300000`.

**Claude Code too old:** dependency auto-install needs v2.1.143+. Run `claude update`, then retry.

## For project repos

Run `/raftkit-dev:init` inside a project repo the first time you open it with raftkit-dev installed. It registers the raftkit marketplace in that repo's `.claude/settings.json` (so teammates get prompted to install raftkit on trust), installs the governance pack, and wires the repo config raftkit-dev expects — one gated transaction, verified before it reports success. Re-running it checks for drift instead of redoing the work.

## Releasing (maintainers)

- `marketplace.json` is the single source of truth for the plugin list and sources. Versions live in each plugin's `plugin.json` only — never in the marketplace entry.
- **A change ships only when its plugin's `version` is bumped** (semver). Un-bumped changes never reach installed machines; CI blocks merging a plugin change without a bump.
- Flow: bump `version` in the plugin's `plugin.json` → PR → squash-merge to `main` → clients pick it up on refresh.
- Future work: version-constrained dependencies require git tags named `{plugin-name}--v{version}` (`claude plugin tag --push`). Do not add version constraints to `dependencies` before that tagging convention is adopted.

CI runs `scripts/validate.sh` on every PR (marketplace + manifest validation, version-bump gate); `tests/validate.test.sh` keeps the gate honest.
