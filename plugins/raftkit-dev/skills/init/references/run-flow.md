# Run flow — one transaction, doctor on re-run

## Phase 1 — Preflight (validate all, write nothing)

1. **Git repository.** `git rev-parse --is-inside-work-tree`. If not a git repo,
   stop with exactly:

   ```
   Not a git repository. Run init from inside a git repo — nothing was written.
   ```

2. **Resolve write targets.** `.claude/settings.json` (may not exist yet) and
   `.raftkit/init.json`. Read the existing settings file if present so Phase 4
   can detect conflicts before Phase 3 touches anything.
3. **Branch/write mode.** Reuse whatever `setup-project` determines for the
   governance pack's commit-vs-PR path — init does not re-derive branch
   protection separately; it shares the same repo state `setup-project` sees.

Any failure here aborts before a single write, exactly as `setup-project`'s own
Phase 1 does.

## Phase 2 — Capability check

Run `raftkit-dev:capability-preflight` and use its verdict verbatim — its
exact strings, its plan format, its hard stop on a refused or unanswered plan.
Init adds nothing here and never re-derives readiness itself. A required
capability that stays missing after a declined or unanswered plan stops the
run with capability-preflight's own refusal string:

```
Required capability unavailable: <capability>. Proposed install command (human approval required): <exact command>. Stopping — no fallback.
```

## Phase 3 — Governance pack

Invoke `raftkit-dev:setup-project` and let it run its own four-phase
transaction untouched. If it aborts (missing raftkit-core, a protected branch
it cannot resolve, any Phase-1 failure of its own), init stops here and writes
nothing in the phases that follow. Report exactly what `setup-project` reported
— init does not paraphrase its failure.

## Phase 4 — Repo config

Run:

```
node plugins/raftkit-dev/skills/init/scripts/merge-settings.mjs .claude/settings.json
```

- Exit `0` — applied (or already matched; script prints `created` / `updated` /
  `no changes`). Stage and commit `.claude/settings.json` alongside the marker.
- Exit `1` — the existing file was not valid JSON; nothing was written. Stop and
  surface the script's reason verbatim.
- Exit `2` — one or more managed keys conflict with an existing value; nothing
  was written. Show every conflict (existing vs. proposed) and ask the
  developer to resolve each — accept the existing value, accept the proposed
  one, or defer — before re-running.

## Phase 5 — Verify + marker

1. Re-read `.claude/settings.json` and confirm every managed key from
   `references/repo-config.md` resolved to its expected value (or an
   explicitly accepted conflict resolution).
2. Confirm `.raftkit/governance-pack.json` exists (proof Phase 3 completed).
3. Write `.raftkit/init.json` (shape in `repo-config.md`).
4. Commit the config + marker in one commit (or the same PR `setup-project`
   opened, if it took the protected-branch path — one PR, not two).

On success emit exactly (`<X>` = this repo's init version, tracked in the
marker):

```
RaftKit init v<X>: capabilities ready, governance pack installed, repo config wired — verified
```

### Partial-failure honesty

If Phase 4 fails after Phase 3 already committed the pack, **do not** emit the
success string or imply a clean run. State plainly which phases completed and
which did not, e.g.: "Governance pack installed and committed; repo config
merge failed — <reason>. Nothing from Phase 4 was written." The pack commit
already exists; only the config step needs a retry.

## Re-run = doctor, not a blind repeat

A re-run is never "do it all again." It diagnoses:

1. Read `.raftkit/init.json`. If absent, this is a first run — go to Phase 1.
2. Re-run Phase 2's capability check (state may have changed since last run).
3. Let `setup-project`'s own re-run logic handle the pack (it already reports
   its own diff and update-in-place).
4. Run `merge-settings.mjs` again — its conflict detection **is** the drift
   check: an unchanged managed key produces `no changes`; a hand-edited managed
   key surfaces as a conflict (exit `2`) with the diff between what's on disk
   and what init expects.
5. If nothing drifted anywhere, emit:

   ```
   RaftKit init: already initialized (init v<X>, pack v<Y>) — no changes
   ```

6. If anything drifted, emit:

   ```
   RaftKit init: <n> item(s) drifted — plan awaiting approval
   ```

   List each drifted item with its diff. Change nothing until the developer
   approves item-by-item or as a whole — silence is not approval.
