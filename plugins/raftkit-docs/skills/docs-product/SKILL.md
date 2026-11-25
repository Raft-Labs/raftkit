---
name: docs-product
description: Design a project's documentation from scratch, document an existing codebase, or scaffold a project — "help me design this project", "document this codebase for me", "set up the project docs", "reverse-engineer the docs", "scaffold the project". Runs the co-authoring design interview and generates docs and diagrams in the repo's own conventions. Parity checks on a story are raftkit-dev:docs.
user-invocable: true
---

# docs-product

Design, generate and reverse-engineer a repo's living docs, in the repo's own documentation system. Load `raftkit-core:rules` first unless it is already in this conversation.

**Discover, then write.** Every structural opinion is a proposal. Existing conventions win. No doc is written before the human signs off on the full plan. Never write to Asana: stories are `raftkit-pm:story`, bugs are `raftkit-qa:bug`. Consume confirmed PM outputs (Project Profile, decisions, stories, approved planning); never re-ask them.

## Modes

State `docs mode: <design|init|audit|sync|verify|scaffold> · branch: <branch>` before any work, even when the mode was inferred. Preflight always runs first; it is not a mode.

- **design** — the twelve-phase co-authoring flow (`references/design-flow.md`) under the interview contract (`references/interview.md`). Nothing is written before sign-off.
- **init** — build the docs foundation from approved planning: a story, the Project Profile, a spec, or a finished design session. With none, offer design; if declined, refuse with the exact line below. Never invent product decisions.
- **audit** — compare docs, or their absence, with the code. Read-only until a change plan is approved. Code without docs is reverse-engineered (`references/existing-docs.md`).
- **sync** — invoke `raftkit-dev:docs` on the explicit change set. Never re-implemented here.
- **verify** — delegated to `raftkit-dev:docs`, which owns the parity check and its two scripts. Never re-implemented here.
- **scaffold** — optional bootstrap after design (`references/scaffolding.md`). Asks before touching anything outside docs; installs route through `raftkit-dev:setup`.

## Preflight

Route per `references/existing-docs.md`:

1. **greenfield** — no code or docs: init with approved planning, otherwise offer design.
2. **existing code, no living docs** — reverse-engineer (Recommended), fresh design, or hybrid.
3. **living docs** — discovered conventions are the yardstick; a missing capability lands only through an approved proposal.

All three end on the same sync and verify contract: `raftkit-dev:docs`.

## Handoff

Read the approved story (live), the Project Profile, any spec the story links, the discovered conventions, the ownership map, open unknowns and the repo's own verification commands. Ask the developer only what repo evidence cannot answer. Before init writes, classify the work complete, partial or missing against the story and spec.

## Templates, diagrams, discovery

`assets/templates/` ships nine adaptable templates: recommended for greenfield, mapped onto existing conventions otherwise, never forced. Generation, diagrams and the graded check are `references/generation.md`.

`raftkit-dev:docs`'s `scripts/audit-docs.mjs` returns the in-memory discovery result. Persist it only as a project-owned descriptor the human approves. On conflicting signals, report both, change nothing, and ask which convention is authoritative.

## Exact strings (owned here)

- `No approved planning output covers this — route it through the story/PM flow before docs init.`

Sync and verify outcome lines are `raftkit-dev:docs`'s own.

## Safety

- Stay inside the repo root. Never follow an out-of-root symlink.
- Skip VCS metadata, dependencies, build output, caches, auth state and secret or env files. Never print a secret; envx presence is metadata only.
- Scripts write only to an explicit output path inside the root. Clean temporary files after verification.
- Use an explicit change set: a selected base, ref or diff, or the confirmed working diff. Never pick a git range silently.
- Capability needs route through `raftkit-dev:setup`. Never improvise an install.

## Guardrails

- **Plain language** — every line a human reads follows `raftkit-core:rules` → Plain output; a house term gets its one-line gloss on first use.

## Never

- Any Asana write; ticking `[AC]` or `Testing`.
- Package-manager and hook work, and running installs (`raftkit-dev:setup`).
- Editing read-only source projects; merging PRs; deploying.

## References

- `references/design-flow.md` — the twelve phases, the per-module loop, the RBAC matrix.
- `references/interview.md` — how questions are asked, push-backs, what to volunteer, the edge-case walk.
- `references/generation.md` — postures, templates, diagrams, graded verification.
- `references/existing-docs.md` — handoff inputs, planning check, discovery, descriptor, reverse-engineering.
- `references/scaffolding.md` — bootstrap, ask-before-touch, never-auto-run.
- `references/story-adapter.md` · `references/bug-adapter.md` — the link registry; drafting routes to `raftkit-pm:story`, filing to `raftkit-qa:bug`.
- `assets/companion/` — the project-local companion, rendered by `scripts/render-companion.mjs`, installed by this plugin, never by `raftkit-dev:setup`.
