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
5a. **pr-auto-review opt-in ask (component 8).** First check
   `.raftkit/governance-pack.json` (if it exists, i.e. this is a re-run —
   see "Re-run and component 8's decline state" below for the exact field
   names and read/write rules): if `pr-auto-review` is already recorded as
   accepted or declined there, skip straight to that recorded outcome
   without asking again. Otherwise (first run, or the developer has asked
   to reconsider), ask explicitly, separate from the rest of the plan:
   "Also install the PR auto-fix workflow? It runs pr-review-toolkit in CI
   on every PR, auto-commits fixes for Critical findings only (one commit
   per fix, auto-reverted if a fix breaks a check), and comments the rest.
   Requires manually adding an ANTHROPIC_API_KEY repo secret afterward —
   this installer cannot do that step for you." A **declined** answer
   excludes component 8 entirely from Phase 2/3 — the other seven proceed
   unaffected. An **accepted** answer adds it to the same all-or-nothing
   transaction (render via `pr-auto-review/scripts/render-pr-auto-review.mjs`,
   stage, commit/PR, verify — same phases as components 3–5 and 7), with the
   manual-secret step printed prominently in the Phase 4 success output,
   not buried.
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

- **CLAUDE.md (components 1 and 6 — protocols and the Module Design
  Standard):** delegate to `claude-md-management` to **merge** both blocks,
  never clobber. An existing CLAUDE.md keeps all its repo-specific content;
  the protocol block and the MDS block are appended/merged as their own
  sections. On a conflicting existing pre-push hook or CodeRabbit config, show
  the incoming vs. existing side by side with a merge proposal and let the
  developer decide — do not silently overwrite a file the developer authored
  (the marker tells you whether a prior *pack* install owns it; a pack-owned
  managed file is replaced, a foreign one is a conflict to resolve).
- **orchestrator, spec template:** write from the live core content — the
  orchestrator to `.claude/skills/orchestrator/SKILL.md` (discoverable-skill
  form), the spec template to `spec_path`.
- **hook, CI, CodeRabbit, MDS ESLint config:** write the four assets;
  substitute `__SPEC_PATH__` and `__SPEC_TEMPLATE_SENTINEL__` in the hook (see
  `components.md`), then `chmod +x .githooks/pre-push` — git ignores a
  non-executable hook under `core.hooksPath`. The MDS ESLint config writes to
  `.raftkit/mds-eslint.config.mjs`, a new file, never merged into any existing
  eslint config the repo already has.
- **pr-auto-review workflow, if accepted at step 5a:** render via
  `pr-auto-review/scripts/render-pr-auto-review.mjs` and stage
  `.github/workflows/pr-auto-review.yml`. If declined, this file is not
  staged and nothing else in this phase changes.
- **version marker:** stage `.raftkit/governance-pack.json`, including
  `optional_components: ["pr-auto-review"]` only if accepted.

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
- **Protocols and MDS agent-readable:** confirm the merged `CLAUDE.md`
  (protocol block **and** Module Design Standard block) and
  `.claude/skills/orchestrator/SKILL.md` are present and readable.
- **MDS ESLint config present:** confirm `.raftkit/mds-eslint.config.mjs`
  exists and is readable. A write that silently failed or was skipped is a
  failed install for this component, not a pass — never claim it "verified"
  in the success line without having actually read the file back.
- **pr-auto-review, if accepted at step 5a:** confirm the rendered
  `.github/workflows/pr-auto-review.yml` contains no unresolved `__…__`
  token (same fail-closed check as components 3–4). This installer
  **cannot** verify the `ANTHROPIC_API_KEY` secret exists — GitHub does not
  expose secret presence to `gh api` reads — so the success output instead
  prints the exact manual step as a **required next action**.

On success emit exactly (with `<X>` = the installed raftkit-core version),
declined component 8:

```output
Governance pack v<X> installed: 5 protocols, spec template, hook, CI, CodeRabbit, design standard, MDS ESLint config — verified
```

Accepted component 8, append additively (never renumber "5" to anything else —
the count-word stays attached to "protocols", and the seven required components
keep their exact wording):

```output
Governance pack v<X> installed: 5 protocols, spec template, hook, CI, CodeRabbit, design standard, MDS ESLint config, pr-auto-review workflow — verified
```

```output
Required next step: add ANTHROPIC_API_KEY to this repo's Actions secrets — Settings → Secrets and variables → Actions → New repository secret.
```

Then print the two one-time lines the dev needs: the per-clone
`git config core.hooksPath .githooks` (see components.md), and the one-line
import that wires the MDS ESLint config into the repo's own `eslint.config.js`
— this installer never edits that file itself:

```
import mds from "./.raftkit/mds-eslint.config.mjs";
export default [...yourExistingConfig, ...mds];
```

## Baseline capabilities — one consolidated, approved, transactional setup

Every initialized RaftKit project must have its **baseline-required**
capabilities present, verified, and activated: claude-mem (the exact provider —
`remember` is never a substitute), task-observer, find-skills (the skill plus
its Skills CLI seam), frontend-design, superpowers, and envx; impeccable is
required-available for UI work and never replaces frontend-design.
capability-preflight classifies each; a missing baseline capability is reported
**missing**, never `optional-not-selected`.

### The consolidated setup plan (one approval)

Setup first **inventories** across every location: installed Claude plugins,
global agent skills, and project agent skills — recording each capability's
enabled/disabled state, exact components, provenance, version, and activation
seam. It then
collects **every** missing baseline capability into **one consolidated setup
plan** that shows, per item: exact source, version, scope, install command,
provenance, license, and expected components. Setup waits for **one explicit
approval** of that whole plan.

### Transactional install with a real boundary

On approval, all approved installs run as **one transaction**, staged and
verified before anything is kept:

- Work is **staged** in isolation from the working tree until commit.
- **Verification runs inside the boundary** — every installed component and its
  activation seam is checked before commit.
- Any required-install failure **discards the whole staged batch** — nothing
  setup wrote in this run is kept — and reports the exact failure with its
  command evidence.
- The PR-fallback path (protected branch) follows the same discard-on-failure
  rule.

This is an all-or-nothing staged transaction, not a per-write journal: it does
not undo a prior successful run's individual writes after the fact. If a
prior-run undo becomes a real need, that is its own follow-up story — this
skill does not claim it today.

### Decline, substitution, licensing, activation

- If the developer **declines** a required capability, setup **stops** and
  reports the project **not ready** — a baseline capability is **never** left
  `optional-not-selected`.
- `claude-mem` is the exact provider; if only `remember` is present, claude-mem
  is still reported missing — **no substitution, ever**.
- Capabilities without a redistribution license (find-skills, envx, impeccable)
  install through their **verified provider channel** (`npx skills add …`,
  `envx skill add`, the impeccable CLI) — never a stripped copy. task-observer
  is **CC BY 4.0**: it may be copied, and its **attribution** (Eoghan Henn /
  rebelytics.com + the repo link) and LICENSE travel with the copy.
- task-observer's **activation instruction** is **merged** safely into the
  project instruction file — appended, never overwriting project-owned content.
- Copied/installed skills are recorded in **`skills-lock.json`** (or the
  generalized equivalent) with a content **hash** and **source** per entry.

### Idempotent re-runs

A re-run updates managed capabilities in place, verifies them, and refreshes
the lockfile; it **never clobbers project-owned files**. A no-change re-run
reports no changes.

## Companion delivery

The project-local docs companion (built by the docs skill,
`skills/docs/assets/companion/`) is delivered to the developer's Claude Code
runtime: `.claude/skills/` (project) or `~/.claude/skills/` (user). RaftKit is
Claude Code and Claude apps only (per `CLAUDE.md`) — there is no cross-runtime
delivery here. Setup **detects** the scope, proposes an **exact destination**,
and installs only after **human approval**.

Frontmatter is **rendered** by `scripts/render-companion.mjs`, never
blind-copied, and validated against Claude Code's current schema before it is
written (fail-closed: a validation failure writes nothing).

## Re-run = update (AC: re-run updates in place, shows diff, repo docs untouched)

A re-run is the update path — there is no separate command: it still
executes Phase 1 → 2 → 3 → 4 in full, including Phase 1's step 5a. The four
steps below describe what changes inside those phases once a marker
already exists — they are not a separate, shorter re-run sequence that
bypasses Phase 1.

1. Read `.raftkit/governance-pack.json`. Compare its `pack_version` to the
   installed raftkit-core version.
2. Re-resolve every component from source (live content + assets +
   `spec_path`).
3. Update the **pack-managed** files in place, **show the diff** of what
   changed, and rewrite the marker.
4. **Leave repo-specific docs untouched** — `branching.md`, any non-protocol
   CLAUDE.md content, and every file not in the component manifest. The
   CLAUDE.md merge (via `claude-md-management`) updates only the protocol
   block and the Module Design Standard block — nothing else in the file.

Idempotent: re-running with no version change re-asserts `core.hooksPath` and
reports no file changes.

### Re-run and component 8's decline state

**Component 8's opt-in ask is not repeated on every re-run.** The marker
records a prior decline in its own field,
`optional_components_declined` (e.g. `["pr-auto-review"]`), parallel to —
and never overlapping with — `optional_components` (accepted items only,
per `components.md`). This is read as part of step 1 above (reading the
marker), and it gates Phase 1 step 5a directly (see step 5a's own text):
if `pr-auto-review` is already in `optional_components`, treat it as
accepted and re-resolve/update it like any other component via step 2; if
it is already in `optional_components_declined`, step 5a skips the ask
silently and leaves it uninstalled; otherwise (neither array mentions it —
first run, or the developer asked to reconsider) step 5a asks normally. A
fresh decline writes `pr-auto-review` into `optional_components_declined`;
a fresh acceptance moves it into `optional_components` and removes it from
`optional_components_declined` if present. The developer can force the ask
again at any time by asking explicitly to reconsider component 8 — that
request removes it from `optional_components_declined` before step 5a
runs, so it fires again.
