# Handoff, discovery, reverse-engineering

## Handoff inputs (read, never re-asked)

1. The approved Asana story, live. Its `[AC]`s and out-of-scope list bound every docs change.
2. The Project Profile: the `Project Profile - <project name>` task (`raftkit-core:rules`).
3. Any spec the story links: a record, not a gate. Never author a competing one.
4. Discovered docs roots and conventions.
5. The ownership and change map, as the repo expresses it.
6. Open unknowns, carried forward visibly.
7. The repo's own verification commands, read from its manifests. Never invented.

A missing or unreadable input stops the run, naming what is missing.

## Planning check before init

Classify the work against the story and any linked spec:

- **complete** → proceed;
- **partial** → the specified part proceeds; the rest routes to the story/PM approval path;
- **missing** → refuse with the init line in SKILL.md and route. Never draft product decisions.

## Branch routing

- No docs root, approved planning, no code → greenfield → init.
- No docs root, real code → audit and reverse-engineer.
- A docs root → living docs; its conventions are the yardstick.

## Discovery

`raftkit-dev:docs`'s `scripts/audit-docs.mjs --root <repo> --json` returns, for this run only: docs roots, convention (`module-indexed`, `flat-ownership-indexed`, `ambiguous`, `none`), index files, ownership mapping (index rows and "Update when you change:" footers), history convention (footer chains or a changes-log), the ADR seam, confidence and conflicts.

To persist it, propose a project-owned descriptor: the exact path inside the repo and the exact content. The human approves both. Its fields are `convention` and an optional `note`; `validate-docs.mjs --convention <path>` rejects any other field and any out-of-root path. A descriptor never overrides what the repo expresses.

On ambiguous discovery or a descriptor-vs-discovery clash: report both with evidence, change no doc, ask which convention is authoritative, and update the loser only after the answer.

## Reverse-engineering

Read-only until the developer approves a change plan; the analysis is the proposal. Mark every statement:

- **confirmed** — name the file that proves it;
- **inferred** — state its basis;
- **unknown** — intent, policy, tone, compliance. It stays visibly unknown.

An inference becomes fact only when a human or code evidence confirms it. Ask only what code cannot answer.

1. Static audit: stack, archetype, instruction-file drift.
2. Foundation reads: entry points, routes, schema, workflows, config.
3. Propose a module grouping from what the code contains; the developer confirms it.
4. Run the per-module loop code-first (`design-flow.md`); interview only the gaps.
5. Infer cross-cuts from the code that implements them.
6. Report code without docs and docs without code.
7. On approval, generate in the discovered or approved convention with `Status: Implemented`, marks intact.
8. Record an initial history entry: code snapshot, date, known limits.
9. Hand off: `raftkit-dev:docs` owns every later sync.

Never document dead code, over-document, or fabricate edge cases.
