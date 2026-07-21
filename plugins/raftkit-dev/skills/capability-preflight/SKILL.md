---
name: capability-preflight
description: This skill is consulted by raftkit-dev skills (setup-project first among them) whenever a workflow needs a third-party capability — before Gate 0 of implement, before setup installs the governance pack, or whenever a provider seam is about to be invoked. It inventories installed plugins and agent skills, classifies every registry capability into one of five readiness states with its evidence, verifies exact components (a named agent, named skills, hooks — never just a plugin name), and drafts install plans that hard-stop for explicit human approval. It never installs, enables, or removes anything on its own, never resolves declared dependencies at runtime, and never lets a downstream skill improvise its own install behavior.
user-invocable: false
---

# capability-preflight

Every raftkit-dev skill orchestrates engines it does not own. This skill is the
single contract for knowing — with evidence, not memory — whether those engines
are actually present, enabled, and shaped the way the registry says, and for
getting missing ones installed **only** through a human-approved plan.

## The one rule that governs everything

**Classify with evidence; change nothing without a human.** The preflight reads
inventories and reports. Every install, enable, or removal is a drafted plan
that hard-stops for explicit approval — silence is not approval, and a refusal
stands. Declared plugin dependencies are resolved only by a human-approved
RaftKit install/update; the preflight verifies them but
**never adds or installs them at runtime**.

## Evidence sources (never memory)

- `claude plugin list --json` — installed plugins, versions, scopes, enabled state.
- `claude plugin details <name>` — exact component inventory and token cost.
- `npx skills list --json` and `npx skills list -g --json` — project/global agent skills.
- An installed skill's own SKILL.md, when the CLI cannot answer.
- `references/providers.md` — the verified registry: capability → provider →
  exact components → policy → ownership.
- `scripts/classify.mjs` — the deterministic classifier over captured CLI
  output; use it for classification and report wording rather than re-deriving
  either by hand.

## The five readiness states (exhaustive)

Every registry capability lands in exactly one, with its evidence source named:

1. **ready** — installed, enabled, and the registry's exact components are
   present in the inventory.
2. **installed-but-disabled** — present but disabled; report the exact enable
   command (e.g. `claude plugin enable expo`). Never treat as ready, never
   silently enable.
3. **missing** — not installed. A declared dependency in this state is an
   **unresolved declared dependency** (see below). An undeclared provider gets
   an install proposal only if the capability is needed or recommended.
4. **incompatible** — installed but the verified component is absent or renamed;
   name the missing component from the inventory diff.
5. **optional-not-selected** — optional/conditional and not selected by the
   current scope; noted, never proposed unprompted.

Rows owned elsewhere are labelled, not classified: Asana connectivity is
`raftkit-core (inherited)` — this preflight never claims or duplicates it — and
the Skills CLI is verified at run time.

## Declared dependencies vs runtime installs

raftkit-dev's plugin.json declares its verified hard dependencies. Those resolve
when a human installs or updates raftkit-dev — that installation is the
approval. If preflight finds one missing anyway, report it as an **unresolved
declared dependency**, give the repair guidance (a human-approved RaftKit
install/update of raftkit-dev), and **stop for human action**. Everything not
declared — optional, conditional, community — flows propose → approve → install
→ verify, and is never auto-proposed as a new dependency.

## Run flow

1. **Inventory.** Capture the plugin and skills listings; stream progress
   (capability n of m) so the developer never stares at silence. A missing
   `claude` or `npx` on PATH stops the run naming the missing tool.
2. **Classify** every registry row with `scripts/classify.mjs` semantics.
3. **Report.** Per-capability table (capability · provider · state · evidence ·
   action), then either the all-clear or the plan block.
4. **Plan (when action is required).** One plan per run. For each missing
   selected provider: provenance (marketplace, version, component type, token
   cost when `claude plugin details` provides it) and the exact command as
   `Proposed install command (human approval required): <exact command>`.
   Install scope is derived only from the parent plugin's approved scope, an
   approved Project Profile / org rule, or an explicit human choice — when none
   exists, ask; never assume a default.
5. **Hard stop.** Wait for the developer's explicit approval of the exact plan.
6. **After approval:** only the approved items install; then verify the exact
   components exist (named skills / agent / hooks — not just the plugin name)
   and report any that don't. State when a plugin reload is required.

## Exact strings (owned here)

- All clear: `Capability preflight: all required capabilities ready.`
- Action required: `Capability preflight: <n> ready, <m> missing, <k> installed-but-disabled — install plan awaiting approval.`
  (counts cover classified provider rows; optional-not-selected and inherited
  rows are listed but not counted)
- Refusal downstream: when a required capability stays unavailable after a
  refused or unanswered plan, the calling flow stops with:
  `Required capability unavailable: <capability>. Proposed install command (human approval required): <exact command>. Stopping — no fallback.`
  It never degrades to a copied implementation of the missing engine.

## Skill discovery

For a capability the registry cannot resolve to any provider, run
`npx skills find <specific query>` — scoped to that capability only. Results are
suggestions with provenance for the human to judge; this skill never installs
them. Secrets are never read or printed while detecting stack signals (e.g.
envx: the *presence* of `.envxrc` / `.env.*.gpg` is the signal, their contents
are off-limits).

## Out of scope

- Installing the governance pack (setup-project owns it; it calls this preflight).
- Asana connectivity ownership (raftkit-core; inherited, never duplicated here).
- Editing plugin.json dependencies at run time (a RaftKit code change by PR).
- Any auto-install, auto-enable, or removal; removal is a separate destructive
  action needing its own explicit approval.

## Reference files

- `references/providers.md` — the verified provider registry and the
  verification-evidence rules (transient failures are never registry facts).
- `scripts/classify.mjs` — deterministic classifier over captured CLI output;
  a pure reader that runs nothing and installs nothing.
