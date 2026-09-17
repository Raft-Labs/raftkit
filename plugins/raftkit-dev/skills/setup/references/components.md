# Components, tokens, settings and the marker

Six components, plus one opt-in seventh. Content the pack installs comes live from `raftkit-core`; the five assets are this skill's own.

| # | Component | Source | Installs to |
|---|---|---|---|
| 1 | Working agreement + Module Design Standard | `raftkit-core:working-agreement` → `references/working-agreement.md` and `references/design-standard.md` (live) | `CLAUDE.md` (merged via claude-md-management) |
| 2 | Pre-push hook | `assets/pre-push` | `.githooks/pre-push`, tracked and `chmod +x`, plus `git config core.hooksPath .githooks` |
| 3 | CI quality guardrail | `assets/quality-guardrail.yml` | `.github/workflows/quality-guardrail.yml` |
| 4 | Review config | `assets/coderabbit.yaml` | `.coderabbit.yaml` |
| 5 | Design-standard ESLint config | `assets/mds-eslint.config.mjs` | `.raftkit/mds-eslint.config.mjs`, a new file, never merged into an existing eslint config |
| 6 | Repo settings | `scripts/merge-settings.mjs` | `.claude/settings.json` |
| 7 | **PR auto-review workflow (opt-in)** | `assets/pr-auto-review.yml` + `assets/fix-loop-prompt.md`, rendered by `scripts/render-pr-auto-review.mjs` | `.github/workflows/pr-auto-review.yml` |

Component 7 is never installed by default: it commits code autonomously (Critical-finding fixes only) and needs a repo secret this skill cannot provision. A decline is recorded and not re-asked unless the developer says to reconsider.

## Rendered tokens

Components 2 and 3 are templates rendered fail-closed by `scripts/render-assets.mjs`; component 4 has no tokens and installs verbatim.

| Token | Value | Validation |
|---|---|---|
| `__PM__` | the detected package manager | enum `pnpm｜npm｜yarn｜bun｜none` |
| `__QUALITY_SCRIPTS__` | approved script names present in the manifest | `[A-Za-z0-9][A-Za-z0-9:_.-]*`, names only; script bodies are never copied |
| `__ABSENT_ROLES__` | quality roles with no script, or `none` | same charset; reported by the hook, never run |
| `__SETUP_BLOCK__` | `none` · `corepack` · `setup-node-cache-any` · `setup-bun` | emitted verbatim from this table, chosen by the human from the detection report |
| `__QUALITY_STEPS__` | one CI run-line per approved script | derived from validated names only |

A declared package-manager version is honoured only as an explicit `x.y.z`; `latest` is rejected and a version is never inferred from a lockfile. Newlines, control characters, command substitutions, backticks and option-like values are rejected. Any validation failure means the renderer emits a reason and must render nothing. After substitution no `__…__` token may remain. Identical approved inputs render byte-identical assets, so an unchanged re-run writes nothing.

Rendered assets carry the literal marker `raftkit-governance-pack` in their header. Marker-owned files are the only ones replaced without asking; an unmarked or symlinked hook or workflow is foreign.

## Toolchain detection

`scripts/detect-toolchain.mjs` implements this contract. Collect every lockfile-family signal (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lock`/`bun.lockb`) and parse the `packageManager` field separately, including its declared version. No signal has precedence:

- exactly one lockfile family with an agreeing field → **detected**;
- multiple lockfile families → **conflict, ask**;
- lockfile and field disagree → **conflict, ask**;
- a manifest with no lockfile → **undetermined, ask** (npm is never inferred from `package.json` alone);
- `packageManager` with no lockfile → report the signal and ask before treating it as authoritative;
- no Node manifest → **non-Node posture**, and the quality steps green-skip.

**No writes occur while detection is conflicting or undetermined.** The report also carries the declared manager version verbatim, the repository's own setup mechanism or `none`, any existing CI convention, and hook and CI ownership. Root orchestration scripts are preferred; quality scripts found only in workspace packages are reported with their locations and need a human choice before any command is generated. Recursive or filter flags are never invented.

## The hook is tracked, not in `.git/hooks`

`.git/hooks/pre-push` is untracked: it cannot join the commit and it vanishes for every other clone. So the hook installs to `.githooks/pre-push` and setup runs `git config core.hooksPath .githooks`. That config is per-clone local state, so every fresh clone runs it once (or re-runs setup, which re-asserts it). Print the line in the summary.

## Managed settings keys

`scripts/merge-settings.mjs` is the only write path to `.claude/settings.json`.

| Key | Managed value |
|---|---|
| `extraKnownMarketplaces.raftkit` | `{ source: { source: "github", repo: "Raft-Labs/raftkit" }, autoUpdate: true }` |
| `enabledPlugins` | `raftkit-core@raftkit`, `raftkit-dev@raftkit`, and the engines above from `claude-plugins-official`, each `true` |
| `model` | `"opusplan"` |
| `attribution` | `{ "commit": "", "pr": "" }` |
| `permissions.allow` | `Bash(git status:*)`, `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(claude plugin list:*)`, `Bash(gh pr view:*)` |

Object keys merge additively and `permissions.allow` is a union, so nothing existing is removed. A managed key whose existing value differs is a conflict: every conflict is reported together and nothing is written (exit 2). Unparseable JSON aborts with its reason and writes nothing (exit 1). Identical inputs produce byte-identical output (exit 0, `no changes`). That same conflict detection is the re-run drift check.

## Conditional capabilities

Hasura is detected, not installed: when the repository has a Hasura config with sibling `migrations/` and `metadata/` directories, the plan offers to record the discovered conventions in `.raftkit/hasura.json` so `raftkit-dev:hasura` reads them instead of re-deriving them. Declining changes nothing else.

## The marker

`.raftkit/governance-pack.json`, tracked:

```json
{
  "pack_version": "<raftkit-core version at install time>",
  "installed_at": "<ISO date>",
  "components": ["working-agreement", "design-standard", "hook", "ci", "review-config", "mds-eslint", "settings"],
  "optional_components": ["pr-auto-review"],
  "optional_components_declined": []
}
```

`optional_components` lists only accepted opt-ins; a declined one goes in `optional_components_declined` so the ask is not repeated. `pack_version` is the raftkit-core version, so a repo carrying an older pack is detected on the next run.
