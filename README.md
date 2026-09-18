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

Installing any role plugin automatically installs `raftkit-core` alongside it. `raftkit-dev` additionally auto-installs six declared dependencies from the official Claude marketplace — `superpowers`, `code-simplifier`, `claude-md-management`, `security-guidance`, `pr-review-toolkit`, `frontend-design` — the engines its skills call by name. Inside a Claude Code session, the same commands work as `/plugin marketplace add` and `/plugin install`. Verify with `claude plugin list` — you should see your role plugin, `raftkit-core`, and (for `raftkit-dev`) the six auto-installed engines.

`raftkit-docs` is optional and installed only where a team wants the full documentation product; day-to-day delivery does not need it.

## Plugins

| Plugin | Who | What |
| --- | --- | --- |
| `raftkit-core` | everyone (auto-installed) | The rules every skill inherits, the working agreement, telemetry hooks |
| `raftkit-pm` | PMs | Project profile, stories (write, amend, check, size), estimation, client updates, meeting decisions, routines |
| `raftkit-dev` | Developers | Repo setup, implement, fix, scope guard, UI, Hasura, docs parity |
| `raftkit-qa` | QA | Test-case suite, per-story run sheets, bugs (file and retest) |
| `raftkit-docs` | optional | The documentation design product: co-authoring flow, templates, diagrams, reverse-engineering |

v2 ships these five plugins; `raftkit-docs` is opt-in. PM and QA plugins target the Claude apps/Cowork runtime; the install path there is pending the org-wide install decision (Asana task 1216551001583573) — until it lands, use Claude Code with the commands above.

## Getting help

Every plugin ships a help command — run it inside a Claude Code session:

```
/raftkit-pm:help        # PM workflow: profile, story, estimate, status, meeting, routine
/raftkit-dev:help       # Dev workflow: setup, implement, fix, scope-guard, ui, hasura, docs
/raftkit-qa:help        # QA workflow: suite, run-sheet, bug
/raftkit-docs:help      # The optional documentation product
/raftkit-core:help      # The shared rules and the working agreement
```

Pass a skill name or question for a focused answer, e.g. `/raftkit-dev:help scope-guard` or `/raftkit-pm:help how do I onboard a project`.

## Renamed in v2

v2 consolidates 35 skills into 18 installed by default, plus 2 in the opt-in docs plugin. The old names are gone; every new skill's description carries the old trigger phrases, so asking in your own words still works.

| v1 | v2 |
| --- | --- |
| `house-rules`, `write-protocol`, `workflow-constants`, `asana-formatting` | `raftkit-core:rules` |
| `governance-protocols`, `design-standard` | `raftkit-core:working-agreement` |
| `project-onboarding` | `raftkit-pm:profile` |
| `user-story`, `story-readiness`, `brainstorm` | `raftkit-pm:story` (write, amend, check, size) |
| `estimation` · `status-update` · `meeting-decisions` | `raftkit-pm:estimate` · `status` · `meeting` |
| `deprecation-sweep`, the meeting-notes routine | `raftkit-pm:routine` |
| `story-skill-generator` | retired |
| `init`, `setup-project`, `capability-preflight`, `pr-auto-review` | `raftkit-dev:setup` |
| `pr`, `simplify`, `ultrathink` | folded into `raftkit-dev:implement` |
| `fix-bug`, `fix-production-error` | `raftkit-dev:fix` |
| `ui-creation`, `recipes` | `raftkit-dev:ui` |
| the docs design product | the opt-in `raftkit-docs` plugin |
| `test-suite` · `test-run-sheet` | `raftkit-qa:suite` · `run-sheet` |
| `file-bug`, `retest` | `raftkit-qa:bug` (file and retest) |

## Updates

New versions arrive automatically via Claude Code's plugin refresh, or on demand:

```bash
claude plugin marketplace update raftkit
```

No need to re-add the marketplace. Installs resolve to the latest stable version; there is no pre-release channel.

## Troubleshooting

**Permission denied / repository not found when adding the marketplace:**
You need access to the RaftLabs GitHub org — ask in #raftkit.

**Stuck install:** installs normally finish in under a minute. If one hangs or times out ("Git clone timed out"), your git auth is usually the cause — run `gh auth status` and re-authenticate. On slow connections, raise the timeout: `export CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS=300000`.

**Claude Code too old:** dependency auto-install needs v2.1.143+. Run `claude update`, then retry.

**`/raftkit-dev:help` (or any `raftkit-*` command) not found:** your marketplace cache may predate the plugin split — an old install can be pinned to a single `raftkit` plugin with no `help` command at all. `claude plugin marketplace update` cannot recover a cache pinned to a rewritten history; remove and re-add instead:

```bash
claude plugin marketplace remove raftkit
claude plugin marketplace add Raft-Labs/raftkit
claude plugin install raftkit-dev@raftkit   # or raftkit-pm / raftkit-qa
```

Confirm with `claude plugin list` — you should see `raftkit-core` plus your role plugin.

## Telemetry

RaftKit measures its own use so we can see who has adopted it and where people get stuck. It runs as plugin hooks in `raftkit-core` — active automatically in Claude Code once any raftkit plugin is installed, with nothing to configure.

**Collected:** your git name and email, GitHub login, OS user; which skills you run; when a skill stops for your approval or hard-stops, and which line it emitted; every prompt you submit, in full; every failed tool call (the tool's name and its error output); plugin and platform versions.

**Also collected:** the repository (`owner/repo`) and branch you are working in, so a blocker can be traced to the project it happened in. **Not collected:** file contents, or anything from a repo you didn't run RaftKit in. Prompts pass through a credential scrubber that strips API keys, tokens, and private-key blocks before anything is sent.

Events spool to a local file and upload in batches to RaftLabs' own admin dashboard (`raftkit.raftlabs.dev`) — no third-party analytics processor, and no credential ships to your machine. A hook can never block or slow your session, and an offline session still reports later rather than losing data.

**Opt out** at any time:

```bash
export RAFTKIT_TELEMETRY=off     # or DO_NOT_TRACK=1
```

When a skill hard-stops, the refusal is reported as telemetry and appears in the admin dashboard with a triage status, so blockers reach the team instead of dying in your terminal. Nothing is filed on any issue tracker: a captured refusal line can carry client project detail, and this repository is public, so that data belongs only behind the dashboard's authentication.

### In Cowork

Cowork sessions run in a sandbox with no host filesystem and no hooks, so none of the above runs there and **`RAFTKIT_TELEMETRY=off` has no effect in Cowork** — it sets an environment variable that only the hooks read.

Cowork reports through its own OpenTelemetry export instead, which an admin turns on once under Admin settings. It covers prompts, tool failures and errors on its own, but emits no event when a skill runs, so each `raftkit-pm` and `raftkit-qa` skill names itself in its first reply — `Using raftkit-pm:story`. That line is the only record that a skill ran at all. No skill calls an endpoint, spools a file, or reports anything itself.

Assistant responses are read for that announcement and for refusals, then dropped — they are never stored. The real switch is the admin's OTLP endpoint: unset it and nothing is exported, for anyone. There is no per-session equivalent inside Cowork. See `raftkit-core/skills/cowork-telemetry`.

## For project repos

Run `/raftkit-dev:setup` inside a project repo the first time you open it with raftkit-dev installed. In one transaction it merges the RaftLabs working agreement and the Module Design Standard into the repo's `CLAUDE.md`, registers the raftkit marketplace in `.claude/settings.json` (so teammates are prompted to install raftkit on trust), installs the pre-push hook, the CI quality guardrail and the review config, and offers the opt-in PR auto-review workflow. It shows the whole plan and stops once before writing anything, then verifies what it wrote. Re-running it reports drift instead of redoing the work.

## Releasing (maintainers)

- `marketplace.json` is the single source of truth for the plugin list and sources. Versions live in each plugin's `plugin.json` only — never in the marketplace entry.
- **A change ships only when its plugin's `version` is bumped** (semver). Un-bumped changes never reach installed machines; CI blocks merging a plugin change without a bump.
- Flow: bump `version` in the plugin's `plugin.json` → PR → squash-merge to `main` → clients pick it up on refresh.
- Future work: version-constrained dependencies require git tags named `{plugin-name}--v{version}` (`claude plugin tag --push`). Do not add version constraints to `dependencies` before that tagging convention is adopted.

CI runs `scripts/validate.sh` on every PR (marketplace + manifest validation, version-bump gate); `tests/validate.test.sh` keeps the gate honest.
