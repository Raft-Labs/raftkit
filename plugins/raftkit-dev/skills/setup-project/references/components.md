# The pack: components, sources, and the version marker

The governance pack is five components. Two kinds of source feed them, and the
distinction is the whole point of this skill:

- **Content owned by `raftkit-core`** — the protocols, the orchestrator
  mechanism, and the spec template. Read these **live from the installed
  `raftkit-core/governance-protocols` skill at install time.** This skill keeps
  **zero copies** of that text; a copy here would drift from the source, the
  exact failure the pack exists to prevent.
- **Artifacts owned by this skill (M3)** — the pre-push hook, the CI
  quality-guardrail workflow, and the CodeRabbit config. These ship as files
  under `assets/` here (governance-protocols does not carry them).

## Component table

| # | Component | Source | Installs to |
|---|---|---|---|
| 1 | Protocols 1–5 (+ orchestrator mechanism) | `raftkit-core/governance-protocols` → `references/protocols.md` and `references/orchestrator.md` (live) | `CLAUDE.md` (merged) and `.claude/skills/orchestrator/SKILL.md` |
| 2 | Active-feature spec template | `governance-protocols` → `references/active-feature-template.md` (live) | `<spec_path>` (default `docs/specs/active-feature.md`) |
| 3 | Pre-push hook | `assets/pre-push` (M3) | `.githooks/pre-push` (tracked, `chmod +x`) + `git config core.hooksPath .githooks` |
| 4 | CI quality guardrail | `assets/quality-guardrail.yml` (M3) | `.github/workflows/quality-guardrail.yml` |
| 5 | CodeRabbit config | `assets/coderabbit.yaml` (M3) | `.coderabbit.yaml` |

Success string counts these five: `5 protocols, spec template, hook, CI,
CodeRabbit`. The orchestrator mechanism travels **with** the protocols component
(Protocol 2 is inert without it) — it is not a sixth component. It installs as a
**discoverable skill** at `.claude/skills/orchestrator/SKILL.md` (a bare `.md`
loose under `skills/` is not a registered skill), still counted inside the
protocols component.

**Not installed by this per-repo skill:** the governance pack's cheat sheet.
It installs to the team workspace (pinned), not a repo file, and this installer
does one repo per run.

## Parameters — from raftkit-core only (AC: parameters sourced from core)

Two values are parameters, not hardcodes. Read both from the
`governance-protocols` **parameter table** at install time; never hand-edit them
per repo.

| Parameter | Default | Used by |
|---|---|---|
| `decomposition_threshold` | `2` | already baked into the protocol text you install verbatim |
| `spec_path` | `docs/specs/active-feature.md` | the spec template's install path (component 2) and the hook's spec gate |

Components 3–4 (the hook, the CI workflow) are **templates rendered
fail-closed** by `scripts/render-assets.mjs` — the exact substitution rules
live here and the script executes them; there is no other rendering path for
those two. Component 5 (`coderabbit.yaml`) has no tokens and installs
byte-verbatim, unrendered — `render-assets.mjs` does not touch it. Tokens:

| Token | Value | Validation |
|---|---|---|
| `__SPEC_PATH__` | the `spec_path` value read from core | as before |
| `__SPEC_TEMPLATE_SENTINEL__` | the live spec template's H1 placeholder | as before |
| `__PM__` | detected package manager | enum `pnpm|npm|yarn|bun|none` only |
| `__QUALITY_SCRIPTS__` | approved, present script names | each matches `[A-Za-z0-9][A-Za-z0-9:_.-]*` and exists as a key in the approved manifest; names only — script bodies are never copied into assets |
| `__ABSENT_ROLES__` | quality roles with no script | same charset, or `none`; reported by the hook, never executed |
| `__SETUP_BLOCK__` | a named, documented option | one of `none` · `corepack` · `setup-node-cache-any` · `setup-bun`, emitted verbatim from this table — chosen by the human from the detection report; no mechanism is ever assumed per manager family |
| `__QUALITY_STEPS__` | one CI run-line per approved script | derived from validated names only |

Rules: a declared `packageManager` version is honored via the repo-supported
mechanism and validated as an explicit `x.y.z` — `latest` is rejected and a
version is never invented from a lockfile. Newlines, control characters,
command substitutions, backticks, and leading-dash/option-like values are
rejected. **Any validation failure means the renderer emits a reason and must render nothing** — no partial output, ever. After substitution no `__…__`
token may remain. Identical approved inputs render byte-identical assets, so an
unchanged re-run produces no file changes.

**Ownership marker:** rendered assets carry the literal marker
`raftkit-governance-pack` in their header. Marker-owned hook and workflow files
are the only files the transaction replaces silently; an unmarked or symlinked
`.githooks/pre-push` or `quality-guardrail.yml` is foreign — show the diff,
propose, and let the developer decide.

## The pre-push hook is a tracked file, not `.git/hooks/`

`.git/hooks/pre-push` is untracked: it cannot join the atomic commit/PR and it
vanishes for every other clone. So the hook installs to a **tracked**
`.githooks/pre-push`, and the install flow runs `git config core.hooksPath
.githooks` to point git at it. That config is **per-clone local state**, so:

- Every teammate cloning fresh must run `git config core.hooksPath .githooks`
  once (or re-run setup-project, which re-asserts it).
- A re-run always re-asserts the config even when the file is unchanged.

Document this line in the install summary so fresh clones know how the hook
activates.

## The version marker (AC: re-run = update in place)

`.raftkit/governance-pack.json` records what was installed so a re-run can tell
v1 from v2 and update in place. Shape:

```json
{
  "pack_version": "<raftkit-core version at install time>",
  "installed_at": "<ISO date>",
  "components": ["protocols", "spec-template", "hook", "ci", "coderabbit"]
}
```

`pack_version` is the installed **raftkit-core** version (the content source), so
a repo carrying pack v1 while core ships v2 is detected on the next run. On a
re-run: if the marker's version differs from the installed core version, update
every pack component in place, show the diff, write the new marker — and leave
repo-specific docs untouched (see install-flow.md).
