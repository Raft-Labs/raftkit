---
name: docs-companion
description: Project-local documentation companion. Keeps this repository's docs and code in lockstep through four always-on gates - session pre-flight drift scan, spec-first refusal (no code without an approved spec), code-edit change-tracking, and the implementation-vs-spec validation gate on any done claim. Activates when the repository has living project documentation or a docs/ tree the team keeps current.
---

# docs-companion

This project-local skill enforces the documentation lifecycle inside the
repository it is installed in. It is built by the raftkit-dev docs skill and
delivered by setup-project; it depends on nothing outside this repository.

## Gate 1 — pre-flight (session start)

On the first substantive message of a session (and after a branch change):
locate the project docs tree, read the root instruction file, list modules
with status, and compare instruction-file claims against the repository
reality. Surface a drift report only when it is non-empty, then ask what
today's work is. In a repo with code but no docs, offer: reverse-engineer
(recommended), fresh design, hybrid, or skip (logged).

## Gate 2 — spec-first (before code)

Any add/build/implement request checks the docs tree for the owning spec
before code is written.

- **Full spec** — read it and implement to match exactly.
- **Partial spec** — fill the gaps first (short interview), then implement.
- **No spec** — draft one first; do not skip ahead to coding. Compromises:
  a timeboxed microspec now, or the spec immediately after in the same
  session. An explicit developer bypass is allowed but recorded as spec debt,
  and done is withheld until it clears.

Bug fixes, behavior-preserving refactors, copy tweaks, tests, performance
work, and dependency upgrades pass without a fresh spec — but still
change-track.

## Gate 3 — code-edit change-tracking

Every code edit is mapped against the docs it invalidates (schema, routes,
pages, components, permissions, workers, configs, env). Affected docs are
updated through the confirmed lifecycle — identify, classify, confirm,
update, record history, ADR when architectural, re-verify — before the next
unrelated task. Multi-edit feature work batches one change-tracking pass at
the natural stopping point. Silent edits are refused.

## Gate 4 — validation (on any done claim)

"Done", "ready to merge", "ship it" trigger the implementation-vs-spec parity
check across the full category list (pages, components, actions, APIs,
schema, state machines, jobs, webhooks, edge cases, telemetry, permissions,
i18n, compliance, tests, diagrams). Blockers stop the claim; an override is
logged with its reason and the module status stays Draft.

## Boundaries

- Never write outside this repository; never touch secrets or decrypt env
  files; never print secret values.
- Never write to project-management systems directly; propose, and let the
  team's approval flow own the write.
- The docs tree's own conventions always win over any structure this skill
  would prefer.
