---
name: init
description: This skill should be used the first time a developer opens a repo with raftkit-dev installed, or whenever they want to check a repo's raftkit config for drift. Trigger on "init this repo", "run raftkit init", "set up raftkit here", "wire this repo for raftkit-dev". It runs the capability check, delegates the governance pack to setup-project, merges house config (marketplace entry, enabled engines, model, attribution, a read-only permissions allowlist) into .claude/settings.json, writes a version marker, and verifies the whole run — all in one gated transaction. A re-run acts as a doctor pass, reporting drift and showing diffs but changing nothing without explicit approval.
user-invocable: true
---

# init

The one command that makes a fresh repo behave the RaftKit way. Before init, a
developer installing raftkit-dev has three manual steps — install the engine
plugins, run `setup-project` for the governance pack, hand-paste the
marketplace entry into `.claude/settings.json` (the README still says to do
this by hand). Each is a silent failure point. `init` runs all three as one
transaction and adds nothing else.

## The two guarantees that govern everything

1. **Orchestrates, rebuilds nothing.** The governance pack is `setup-project`'s
   — init calls it and never reimplements a byte of it. Capability checking is
   `raftkit-dev:capability-preflight`'s when that skill is installed — init
   delegates to it entirely. Init's own scope is exactly one thing nothing else
   owns: repo-level Claude Code configuration.
2. **Fail-closed, human-gated.** Every write goes through
   `scripts/merge-settings.mjs`, which never partially writes: a conflict or a
   malformed input aborts with nothing written. A missing capability produces
   one consolidated install plan and waits for one explicit approval — never
   installed piecemeal, never auto-installed.

## Preconditions

- **A git repository.** Otherwise stop with the exact non-git message (see
  `references/run-flow.md`) and write nothing.
- **raftkit-core installed.** `setup-project` needs it as its content source;
  init inherits that precondition rather than restating it.

## Run flow

Work `references/run-flow.md` in order:

1. **Preflight — validate all, write nothing.** Confirm the git repo, resolve
   every write target, detect conflicts.
2. **Capability check.** Delegate to `raftkit-dev:capability-preflight` when
   installed; otherwise run the interim fallback in `references/repo-config.md`
   — one consolidated plan, one approval, no piecemeal installs. A required
   capability that stays missing after a declined plan stops the run.
3. **Governance pack.** Delegate to `raftkit-dev:setup-project` unchanged. If it
   aborts, init writes nothing further and stops.
4. **Repo config.** Run `scripts/merge-settings.mjs` against
   `.claude/settings.json` — see `references/repo-config.md` for the managed
   key table and the merge/conflict rules.
5. **Verify + marker.** Re-read what was written, confirm it resolved, write
   `.raftkit/init.json`, then emit the exact success string.

Phases 3 and 4 are separate commits — if 4 fails after 3 already landed, report
**exactly which phase completed**. Never claim a clean whole run that didn't
happen.

## Re-run is the doctor path

Re-running is never a blind repeat. It compares `.raftkit/init.json` against
the live state of every managed item: no drift reports the exact
already-initialized string with zero file changes; drift on any item shows its
diff and changes only what the developer explicitly approves. See
`references/run-flow.md` for the exact strings.

## Guardrails

- **Never reimplement `setup-project` or `capability-preflight`.** A gap in
  either belongs to that skill's story, not a copy pasted in here.
- **Merge, never clobber.** Unmanaged keys and existing values in
  `.claude/settings.json` are untouched. A conflicting existing value on a
  managed key is reported for the developer to resolve, never overwritten
  silently.
- **`.claude/settings.local.json` is out of bounds.** Personal-scope overrides
  are the developer's, never init's.
- **Escalate to founders** per `raftkit-core/house-rules` if wiring a repo
  implies a scope, contract, or client-relationship risk beyond the repo
  itself.

## Out of scope

- **Asana project / Project Profile binding** — its canonical home is still an
  open decision (Asana `1216550765662503`); init does not guess at it.
- **A "next steps" summary block** — deliberately left out of this story.
- **The governance pack itself** — owned by `setup-project`; delegated to, never
  duplicated.
- **The capability registry and its classifier** — owned by
  `capability-preflight`; init's own fallback exists only until that skill
  merges (see the removal note in `references/repo-config.md`).

## Reference files

- `references/run-flow.md` — the five-phase transaction, the exact strings,
  and the doctor re-run.
- `references/repo-config.md` — the managed settings-key table, the merge and
  conflict rules, the marker shape, and the interim capability-check fallback
  with its removal condition.
- `scripts/merge-settings.mjs` — the only write path to `.claude/settings.json`;
  deterministic, fail-closed, byte-identical on an unchanged re-run.
