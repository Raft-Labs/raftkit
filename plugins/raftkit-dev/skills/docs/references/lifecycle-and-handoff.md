# Lifecycle and handoff

The two-surface split is preserved: planning, product decisions, and story
approval live with raftkit-pm in Cowork; this skill owns the repository side —
preflight, discovery, reverse engineering, spec-first enforcement,
synchronization, change history, and completion verification. Neither side
re-does the other's work.

## The handoff inputs (read, never re-asked)

1. **The approved Asana story** — fetched live, scope authority. Its `[AC]`s
   and Out-of-scope list bound every docs change.
2. **The Project Profile** — project facts. Its home is a parameter supplied by
   the project/PM setup; never hardcode a path or connector.
3. **The `spec_path` implementation spec** — the governance pack's spec file is
   THE spec gate. This skill checks it; it never authors a competing format.
4. **Discovered docs roots and conventions** — from `scripts/audit-docs.mjs`.
5. **The ownership/change map** — as the repo expresses it (index tables,
   per-doc footers); reused as found.
6. **Open unknowns** — carried forward visibly, never silently resolved.
7. **Repository verification commands** — the repo's own scripts, read from its
   manifests/docs; never invented.

A missing or unreadable input stops the run naming exactly what is missing —
never proceed on memory or guesses.

## Spec-first classification

Before any docs mutation, classify the work against the spec + story:

- **complete** — the spec and story cover the change → proceed.
- **partial** — some of it is specified → the specified part may proceed; the
  rest routes to the owning story/PM approval path first.
- **missing** — no approved planning covers it → refuse (`No approved planning
  output covers this — route it through the story/PM flow before docs init.`)
  and route; never draft product decisions to fill the gap.

## Mode announcement

Always state `docs mode: <mode> · branch: <branch>` before acting, even when
the mode was inferred. The three branches (greenfield handoff · existing code
without living docs · living docs) converge on the same sync/verify contract
once the branch-specific entry work is done.

## Sync boundary

Synchronize at the boundary of an approved logical change set — in the same
workflow that changed behavior. Never per-keystroke; never deferred past the
turn/commit/PR where the work is presented as complete.
