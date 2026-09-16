---
name: setup
description: Wire a repository for RaftKit in one transaction — "set up this repo", "run raftkit init", "install the governance pack", "update the governance pack", "set up the PR review bot". Installs the working agreement and design standard into CLAUDE.md, the repo settings, the pre-push hook, the CI guardrail and the review config, then verifies. A re-run is the drift check.
user-invocable: true
---

# setup

Everything a repo needs to behave the RaftKit way, installed once and verified. `raftkit-core:rules` apply. A re-run is the update and the drift check; there is no second command.

**All-or-nothing.** Validate everything first, apply in one commit (or one PR on a protected branch), then verify. Content comes live from `raftkit-core:working-agreement`; this skill keeps no copy and authors only its own assets.

## Run

1. **Check, write nothing.** Confirm a git repository; otherwise stop:

```output
Not a git repository. Run setup from inside a git repo — nothing was written.
```

   Confirm `raftkit-core` is installed; without it there is no content to install. Run `claude plugin list --json` once and check the engines `implement`, `fix` and `ui` call by name: superpowers, pr-review-toolkit, code-simplifier, claude-md-management, security-guidance, frontend-design. Name any missing or disabled one with its command, and carry on:

```output
Missing: superpowers. Install it with: claude plugin install superpowers@claude-plugins-official
Setup continues without it; the skills that need it will say so.
```

2. **Detect the toolchain** with `scripts/detect-toolchain.mjs` and resolve every component per `references/components.md`. Conflicting signals, a foreign hook owner, or several `core.hooksPath` values become questions in the draft. An existing `.raftkit/governance-pack.json` makes this a re-run and says what changed.
3. **Stop once** with the whole plan: every file to write with its diff, the toolchain the hook and CI will use, whether this is a commit or a PR, and the PR auto-review workflow as a separate labelled line the developer opts into by name. A re-run shows only what drifted, and reports no changes when nothing did.

```output
Setup plan for <repo>: 6 files (2 new, 4 updated), one commit on <branch>.
**STOP** — approve to apply, edit to change, or decline.
```

4. **On go**, apply everything in one commit, set `core.hooksPath`, then verify: the hook is executable and fires under `git push --dry-run` (never a real push), the merged `CLAUDE.md` is readable, each written file exists, and any rendered asset carries no unresolved token. Write the marker. Report:

```output
RaftKit setup v<X>: working agreement, design standard, repo settings, hook, CI guardrail, review config — verified
```

   Accepting the PR auto-review workflow appends it to that line and prints the one manual step this skill cannot do:

```output
Required next step: add ANTHROPIC_API_KEY to this repo's Actions secrets — Settings, Secrets and variables, Actions, New repository secret.
```

## Never

- Clobber. An existing `CLAUDE.md` keeps its own content; a foreign hook or review config is shown side by side and the developer decides. Only files this pack's marker owns are replaced.
- Touch `.claude/settings.local.json`, or global or system git config.
- Edit GitHub org settings. A protected branch gets the identical change set as a PR.
- Paraphrase the working agreement or the design standard; both install byte-for-byte from core.
