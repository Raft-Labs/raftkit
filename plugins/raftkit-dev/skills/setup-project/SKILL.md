---
name: setup-project
description: This skill should be used when a developer or tech lead wants to install, set up, update, or re-run RaftLabs' governance pack on a repository — CLAUDE.md protocols 1–5, the active-feature spec template, the pre-push hook, the CI quality-guardrail workflow, and the CodeRabbit config — idempotently and all-or-nothing. Trigger on "set up this repo", "install the governance pack", "add the protocols to this repo", "update the governance pack", "run setup-project". It reads the protocol content and parameters live from raftkit-core (never hand-edited per repo), merges rather than clobbers an existing CLAUDE.md, falls back to a PR on protected branches, records a pack version for update runs, and verifies the install before reporting success.
user-invocable: true
---

# setup-project

Install the full RaftLabs governance pack on any repo with one command:
CLAUDE.md protocols 1–5, the spec template, the pre-push hook, the CI
quality-guardrail workflow, and CodeRabbit config — so the rules live in files
the repo carries, not in anyone's memory (PRD §5.3).

Hand-copying protocols drifts. This installer versions the pack and makes an
update a re-run: the same command that installs v1 upgrades it to v2 in place,
shows the diff, and leaves every repo-specific file untouched.

## The two guarantees that govern everything

1. **All-or-nothing.** The install is one transaction. Validate every component
   first; apply them in a single commit (or PR); never leave a repo half-applied.
   Any component that cannot be installed aborts the run with nothing written.
2. **Content comes live from raftkit-core, never from here.** The protocols, the
   orchestrator mechanism, and the spec template are read from the installed
   `raftkit-core/governance-protocols` skill at install time. This skill keeps
   **zero copies** of that text — a copy would drift from the source. It authors
   only its own three artifacts (hook, CI, CodeRabbit config).

And: parameters (`decomposition_threshold`, `spec_path`) come from raftkit-core's
parameter table — never hand-edited per repo.

## Preconditions

- **A git repository.** If the working directory is not a git repo, stop with the
  exact non-git message (see `references/install-flow.md`, Phase 1) and write
  nothing.
- **raftkit-core installed.** It is the source of the protocol content and the
  parameters. If it is missing, stop — there is nothing faithful to install.

## Run flow

Work `references/install-flow.md` in order — it is the transaction:

1. **Preflight — validate all, write nothing.** Confirm the git repo, confirm
   `raftkit-core/governance-protocols` is readable, read the parameter table
   (`decomposition_threshold`, `spec_path`), run `raftkit-dev/capability-preflight`
   (an unresolved declared dependency stops the run with its repair guidance;
   provider installs happen only for a plan the developer explicitly approved),
   resolve every component's source and target, detect conflicts, and determine
   whether the branch is protected. Any failure aborts here before a single write.
2. **Assemble — staged, reversible.** Build the whole change set without
   committing: merge the protocols into CLAUDE.md via `claude-md-management`
   (never clobber), write the orchestrator (to `.claude/skills/orchestrator/SKILL.md`)
   and spec template from live core content, write the three assets (substituting
   `spec_path` and the template sentinel in the hook, then `chmod +x` it), and
   stage the version marker.
3. **Apply atomically.** Unprotected branch → one commit (hook staged with its
   executable bit) + `git config core.hooksPath .githooks`. Protected branch —
   detected via `gh api`, or on a rejected direct push — → open a PR with the
   identical change set instead of committing (client-side only — never touches
   org settings).
4. **Verify — mandatory.** Confirm `.githooks/pre-push` is executable and fires
   via `git push --dry-run` (never a real push), and the merged protocols /
   orchestrator are agent-readable. Only then emit the exact success string, then
   print the one-time `git config core.hooksPath .githooks` line for fresh clones.

See `references/components.md` for the five components, their sources, install
targets, the parameter substitution, and the version-marker shape.

## Re-run is the update path

Re-running compares the marker's `pack_version` to the installed raftkit-core
version, updates the pack-managed files in place, **shows the diff**, rewrites the
marker, and leaves repo-specific docs (`branching.md`, non-protocol CLAUDE.md
content, anything outside the manifest) untouched. Re-running with no version
change re-asserts `core.hooksPath` and reports no file changes. Details in
`references/install-flow.md`.

## Guardrails

- **Verbatim from core.** Protocol text, the orchestrator, and the spec template
  install byte-for-byte from raftkit-core; the only substitution anywhere is
  `spec_path` into the hook. Never paraphrase or regenerate protocol content.
- **Merge, never clobber.** An existing CLAUDE.md keeps all its repo-specific
  content. A conflicting foreign hook or CodeRabbit config is shown side by side
  with a merge proposal for the developer to decide — only pack-managed files
  (per the marker) are replaced silently.
- **Parameters from core only.** `decomposition_threshold` and `spec_path` are
  read from core every run; a repo never hand-edits them.
- **Client-side only.** The protected-branch path raises a PR; it never edits
  GitHub rulesets, environments, or any org setting.
- **Escalate to founders** per `raftkit-core/house-rules` if setup implies a
  scope, contract, or client-relationship risk beyond the repo itself.

## Out of scope

- **Authoring protocol content** — owned by `raftkit-core/governance-protocols`;
  read live here, never authored or cached.
- **GitHub org settings** (rulesets, environments) — owned by the release-train
  rollout; this skill only detects protection and falls back to a PR.
- **CodeRabbit licensing** — the config file installs; the licensing decision
  (open, Asana `1216551482947559`) is untouched.
- **The pack cheat sheet** — a team-workspace artifact, not a repo file; this
  per-repo installer does not place it.

## Reference files

- `references/install-flow.md` — the four-phase transaction (preflight →
  assemble → apply → verify), the exact non-git and success strings, the
  protected-branch PR fallback, and the re-run/update path.
- `references/components.md` — the five components, live-vs-M3 sources, install
  targets, the `spec_path` substitution, the tracked-hook rationale, and the
  version-marker shape.
- `references/assets/` — the three M3-owned artifacts installed verbatim:
  `pre-push`, `quality-guardrail.yml`, `coderabbit.yaml`.
