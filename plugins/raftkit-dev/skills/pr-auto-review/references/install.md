# Installing pr-auto-review as setup-project's opt-in component 8

This skill does not install itself standalone in the normal case — it is
offered by `setup-project` as an **explicitly opt-in** eighth component,
alongside the existing seven (protocols, spec template, pre-push hook, CI
quality-guardrail, CodeRabbit config, Module Design Standard, MDS ESLint
config). See
`setup-project/references/components.md` and `install-flow.md` for the
wiring (added in a later task of this plan) — this file documents
pr-auto-review's side of that contract.

## Why opt-in, not bundled by default

Components 1–5 are either inert scaffolding or narrowly-scoped automation
that never writes code on its own. This workflow commits code to the PR
branch autonomously — qualitatively different, and it requires a manual
secret (`ANTHROPIC_API_KEY`) the installer cannot provision. Bundling it
silently would mean autonomous-commit behavior turning on without a
dedicated confirmation step.

## What the opt-in ask looks like

`setup-project` asks, separately from the rest of its plan: "Also install
the PR auto-fix workflow? It runs pr-review-toolkit in CI on every PR,
auto-commits fixes for Critical findings only (one commit per fix,
auto-reverted if a fix breaks a check), and comments the rest. Requires
manually adding an ANTHROPIC_API_KEY repo secret afterward — this installer
cannot do that step for you."

A **decline** excludes this component entirely; the other five proceed
unaffected, and the decline is not reported as "not ready" — unlike the
baseline-capabilities gate in `install-flow.md`, this component is opt-in,
not required, so declining it never blocks the rest of the install.

An **accept** adds it to the same all-or-nothing transaction as the other
components (render, stage, commit/PR, verify), with the manual-secret step
printed prominently in the install's success output as a **required next
action**, not a buried note.

## What gets rendered

`scripts/render-pr-auto-review.mjs` (a sibling script, not a modification of
`setup-project`'s own `render-assets.mjs`, to avoid touching that script's
existing fail-closed guarantees for its own two components — that script's
template set is hardcoded to `pre-push` and `quality-guardrail.yml` only)
renders `references/assets/pr-auto-review.yml` to
`.github/workflows/pr-auto-review.yml`, carrying the same
`raftkit-governance-pack` ownership marker in its header that
`setup-project`'s other rendered assets carry, plus the `__BOT_COMMIT_EMAIL__`
token the self-trigger loop guard checks against at CI runtime (see
`workflow-mechanics.md`) — a fixed, documented value substituted once here,
never invented per run. Same fail-closed contract as `render-assets.mjs`:
validate every input, substitute every token, verify no `__…__` placeholder
survives, and render nothing on any validation failure.

`references/assets/fix-loop-prompt.md` is **not** templated — it's a static
asset, identical for every client repo, embedded into the rendered YAML's
`prompt:` input.

## Ownership marker: silent replace vs. foreign-file proposal

This follows `components.md`'s existing marker rule exactly — component 8
introduces no new marker semantics, just one more file under it:

- If `.github/workflows/pr-auto-review.yml` does not exist, or exists and
  already carries the `raftkit-governance-pack` marker in its header (a
  prior pack install owns it), the transaction **writes or replaces it
  silently** — same as any other pack-managed file on a re-run.
- If a file already exists at that path **without** the marker (hand-written
  by the team, or owned by some other tool), it is **foreign**: the install
  never overwrites it. It shows the incoming vs. existing content side by
  side as a merge proposal, and only the developer's explicit decision
  applies it — identical to how `install-flow.md` Phase 1 step 5 handles a
  foreign, unmarked `.githooks/pre-push` or `quality-guardrail.yml`.

## What verify means for this component

`setup-project`'s Phase 4 (mandatory verify) can confirm the rendered YAML
contains no unresolved `__…__` token — the same fail-closed check as its
other rendered components. It **cannot** confirm the `ANTHROPIC_API_KEY`
secret exists, since GitHub does not expose secret presence to `gh api`
reads. The success output therefore prints the manual secret step as a
required next action, not an optional note.
