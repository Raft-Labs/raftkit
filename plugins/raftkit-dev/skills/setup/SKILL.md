---
name: setup
description: Wire a repository for RaftKit in one transaction — "set up this repo", "run raftkit init", "install the governance pack", "update the governance pack", "set up the PR review bot". Installs the working agreement and design standard into CLAUDE.md, the repo settings, the pre-push hook, the CI guardrail and the review config, then verifies. A re-run is the drift check.
user-invocable: true
---

# setup

Everything a repo needs to behave the RaftKit way, installed once and verified. Load `raftkit-core:rules` first unless it is already in this conversation. A re-run is the update and the drift check; there is no second command.

**All-or-nothing.** Validate everything first, apply in one commit (or one PR on a protected branch), then verify. Content comes live from `raftkit-core:working-agreement`; this skill keeps no copy and authors only its own assets.

## Run

1. **Check, write nothing.** Confirm a git repository; otherwise stop:

```output
Not a git repository. Run setup from inside a git repo — nothing was written.
```

   Run `scripts/check-engines.mjs --root <repo>` once. Exit 3 means `raftkit-core` is missing and there is nothing to install: stop. Each missing or disabled engine is named with its command, and setup carries on:

```output
Missing: superpowers. Install it with: claude plugin install superpowers@claude-plugins-official
Setup continues without it; the skills that need it will say so.
```

   The same report names each enabled plugin's Stop hook that can block the stop, with its disable command, and the plugins this repo's stack does not use. Setup changes neither on its own; each is a draft line.

2. **Detect the toolchain** with `scripts/detect-toolchain.mjs` and resolve every component per `references/components.md`. Conflicting signals, a foreign hook owner, several `core.hooksPath` values, or a `CLAUDE.md` the splice refuses become questions in the draft. An existing `.raftkit/governance-pack.json` makes this a re-run and says what changed.
3. **Stop once** with the whole plan: every file to write with its diff, the toolchain the hook and CI will use, whether this is a commit or a PR, and each opt-in in `references/components.md` as a separate labelled line the developer accepts by name. A re-run shows only what drifted, and reports no changes when nothing did.

```output
Setup plan for <repo>: 6 files (2 new, 4 updated), one commit on <branch>.
**STOP** — approve to apply, edit to change, or decline.
```

4. **On go**, apply everything in one commit, set `core.hooksPath`, then verify: the hook is executable and fires under `git push --dry-run` (never a real push), the `CLAUDE.md` block matches its sha256, each written file exists, and any rendered asset carries no unresolved token. Write the marker. Report:

```output
RaftKit setup v<X>: working agreement, design standard, repo settings, hook, CI guardrail, review config — verified
```

   Then the one-time wiring this installer never does itself:

```output
In your eslint.config.js:
import mds from "./.raftkit/mds-eslint.config.mjs";
export default [...yourExistingConfig, ...mds];
```

   Accepting the PR auto-review workflow appends it to the success line and prints the one manual step this skill cannot do:

```output
Required next step: add ANTHROPIC_API_KEY to this repo's Actions secrets — Settings, Secrets and variables, Actions, New repository secret.
```

## Never

- Clobber. An existing `CLAUDE.md` keeps its own content; a foreign hook or review config is shown side by side, secret-looking values redacted and filenames, line numbers and command structure intact, and the developer decides. Only files this pack's marker owns are replaced.
- Touch `.claude/settings.local.json`, or global or system git config.
- Edit GitHub org settings. A protected branch gets the identical change set as a PR.
- Paraphrase the working agreement or the design standard; both install byte-for-byte from core.
