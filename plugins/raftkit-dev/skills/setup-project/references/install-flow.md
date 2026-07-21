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
3. **Capability preflight.** Run `raftkit-dev:capability-preflight` and read its
   report. An **unresolved declared dependency** of raftkit-dev stops the run
   with its repair guidance — resolve it through a
   human-approved RaftKit install/update of raftkit-dev; setup-project never
   installs a declared dependency itself, manually or silently. Optional/conditional providers the
   preflight proposes may join this install **only** after the developer
   explicitly approves that exact plan; unapproved items are skipped, never
   installed.
4. **Toolchain and ownership detection** (run `scripts/detect-toolchain.mjs`;
   the decision table below is the contract it implements). First collect every lockfile-family
   signal (pnpm-lock.yaml, package-lock.json, yarn.lock,
   bun.lock/bun.lockb) and parse the `packageManager` field separately,
   including its declared version — no signal has precedence:
   - exactly one lockfile family with an agreeing field → **detected**;
   - multiple lockfile families → **conflict — ask**;
   - lockfile vs field disagreement → **conflict — ask**;
   - package.json without a lockfile → **undetermined — ask** (npm is never
     inferred from package.json alone);
   - packageManager without a lockfile → **report the signal, ask** before
     treating it as authoritative;
   - no Node manifest → **non-Node posture** (green-skip quality steps).

   **No writes occur while detection is conflicting or undetermined.** The
   detection report also carries: the declared manager version (verbatim, never
   invented), the repository-declared setup mechanism (e.g. Corepack via
   `packageManager`) or `none`, any existing CI setup convention, and hook/CI
   ownership (below). Root orchestration scripts are preferred; quality scripts
   found only in workspace packages are reported with their locations and
   require human selection before any command is generated — recursive or
   filter flags are never invented.
5. **Resolve every component's plan** (see `components.md`): the live content for
   1–2, the rendered assets for 3–5 (from the detection + human approvals, via
   `scripts/render-assets.mjs` — fail-closed), and the target paths. Hook and CI
   ownership from the detection decides Phase 2 handling: pack-marker-owned
   files update through the transaction; a foreign owner (Husky,
   simple-git-hooks, Lefthook, unmarked `.githooks` or workflow, or any
   `core.hooksPath` from local, worktree, inherited, or global scope without
   the marker) gets a side-by-side merge proposal — shown with secret-looking
   values redacted while filenames, line numbers, and command structure remain
   — and only the developer's decision applies it. Global or system git
   configuration is never modified. Multiple `core.hooksPath` values → stop
   and ask.
6. **Branch/write mode.** Determine whether the current branch is protected.
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

Approved provider installs from the Phase 1 preflight run here as part of the
same all-or-nothing transaction: a failed approved install aborts the run like
any other component failure.

## Phase 4 — Verify (mandatory)

The install is not done until it is verified:

- **Approved providers verified by component:** for each provider installed in
  Phase 3, confirm the exact components from the capability-preflight registry
  exist (named skills / agent / hooks — not just the plugin name); name any that
  are missing.

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
