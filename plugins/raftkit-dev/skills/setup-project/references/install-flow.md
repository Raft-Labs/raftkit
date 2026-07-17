# Install flow — all-or-nothing, verified, idempotent

The install is one transaction: validate everything first, then apply everything
in a single commit (or PR), then verify. A repo is never left half-configured.

## Phase 1 — Preflight (validate all, write nothing)

Run every check before touching a single file. If any fails, stop with its exact
message and write **nothing** — no marker, no file, no config.

1. **Git repository.** `git rev-parse --is-inside-work-tree`. If it is not a git
   repo, stop with exactly:

   ```
   Not a git repository. Run setup-project from inside a git repo — nothing was written.
   ```

2. **Source reachable.** Confirm the installed `raftkit-core/governance-protocols`
   skill and its `references/` are readable, and read the parameter table
   (`decomposition_threshold`, `spec_path`). If core is missing, stop — the pack
   content has no source. Never substitute remembered protocol text.
3. **Resolve every component's plan** (see `components.md`): the live content for
   1–2, the three M3 assets for 3–5, the `spec_path` substitution for the hook,
   and the target paths. Detect conflicts now (existing hook, existing CLAUDE.md,
   existing CodeRabbit config) so they are handled in Phase 2, not discovered
   mid-write.
4. **Branch/write mode.** Determine whether the current branch is protected.
   Prefer `gh api` (the branch-protection endpoint) when `gh` is available and
   authenticated; if it reports protection, plan the PR path. When `gh` is
   absent or the query is inconclusive, do not assume — attempt the direct
   commit in Phase 3 and treat a **rejected push** as the trigger for the PR
   fallback. This selects commit vs. PR in Phase 3.

All-or-nothing means Phase 1 gates the whole run: any single component that
cannot be installed aborts here, before anything is written.

## Phase 2 — Assemble (staged, still reversible)

Build the full change set without committing:

- **CLAUDE.md (component 1, protocols):** delegate to `claude-md-management` to
  **merge** the protocols, never clobber. An existing CLAUDE.md keeps all its
  repo-specific content; protocols are appended/merged. On a conflicting existing
  pre-push hook or CodeRabbit config, show the incoming vs. existing side by side
  with a merge proposal and let the developer decide — do not silently overwrite
  a file the developer authored (the marker tells you whether a prior *pack*
  install owns it; a pack-owned managed file is replaced, a foreign one is a
  conflict to resolve).
- **orchestrator, spec template:** write from the live core content — the
  orchestrator to `.claude/skills/orchestrator/SKILL.md` (discoverable-skill
  form), the spec template to `spec_path`.
- **hook, CI, CodeRabbit:** write the three assets; substitute `__SPEC_PATH__`
  and `__SPEC_TEMPLATE_SENTINEL__` in the hook (see `components.md`), then
  `chmod +x .githooks/pre-push` — git ignores a non-executable hook under
  `core.hooksPath`.
- **version marker:** stage `.raftkit/governance-pack.json`.

If anything here fails, discard the staged work — nothing is committed.

## Phase 3 — Apply atomically

- **Unprotected branch:** stage all pack paths (the hook staged with its
  executable bit — `git update-index --chmod=+x .githooks/pre-push` if needed)
  and make **one commit** (conventional-commit title). Set `git config
  core.hooksPath .githooks`.
- **Protected branch (AC: protected → PR):** the fallback when protection is
  detected in Phase 1 **or** a direct push is rejected — create a branch, commit
  the same change set there, and **open a PR** instead of committing to the
  protected branch. The change set is identical; only the delivery differs. This
  is a client-side fallback — it never edits GitHub org settings or branch
  rulesets (out of scope).

## Phase 4 — Verify (mandatory)

The install is not done until it is verified:

- **Hook fires:** confirm `core.hooksPath` is `.githooks` and the hook file is
  executable (`test -x .githooks/pre-push`), then fire it with
  `git push --dry-run` **only** — that runs the pre-push hook with zero side
  effects. This skill never performs a real push to verify.
- **Protocols agent-readable:** confirm the merged `CLAUDE.md` and
  `.claude/skills/orchestrator/SKILL.md` are present and readable.

On success emit exactly (with `<X>` = the installed raftkit-core version):

```
Governance pack v<X> installed: 5 protocols, spec template, hook, CI, CodeRabbit — verified
```

Then print the one-time per-clone line teammates need:
`git config core.hooksPath .githooks` (see components.md).

## Re-run = update (AC: re-run updates in place, shows diff, repo docs untouched)

A re-run is the update path — there is no separate command.

1. Read `.raftkit/governance-pack.json`. Compare its `pack_version` to the
   installed raftkit-core version.
2. Re-resolve every component from source (live content + assets +
   `spec_path`).
3. Update the **pack-managed** files in place, **show the diff** of what
   changed, and rewrite the marker.
4. **Leave repo-specific docs untouched** — `branching.md`, any non-protocol
   CLAUDE.md content, and every file not in the component manifest. The
   CLAUDE.md merge (via `claude-md-management`) updates only the protocol block.

Idempotent: re-running with no version change re-asserts `core.hooksPath` and
reports no file changes.
