# Lifecycle and handoff

One product, two surfaces: PM (raftkit-pm in Cowork) can originate Project
Profiles, decisions, stories, and approved planning; this skill consumes those
outputs when they exist and runs the full design/generation workflow when invoked directly
by a developer. Both surfaces share the same templates, references, and
lifecycle semantics. Confirmed facts are consumed, never re-asked; neither
surface loses a capability because the other also provides it. This skill owns
the repository side — preflight, discovery, design and generation, reverse
engineering, and the planning check before init. Sync and completion
verification are `raftkit-dev:docs`.

## The handoff inputs (read, never re-asked)

1. **The approved Asana story** — fetched live, scope authority. Its `[AC]`s
   and Out-of-scope list bound every docs change.
2. **The Project Profile** — project facts. It is the
   `Project Profile - <project name>` task in the project
   (`raftkit-core:rules`); never hardcode a path or connector.
3. **Any implementation spec the story links** — a record, not a gate. This
   skill reads it; it never authors a competing format.
4. **Discovered docs roots and conventions** — from `raftkit-dev:docs`'s
   `scripts/audit-docs.mjs`.
5. **The ownership/change map** — as the repo expresses it (index tables,
   per-doc footers); reused as found.
6. **Open unknowns** — carried forward visibly, never silently resolved.
7. **Repository verification commands** — the repo's own scripts, read from its
   manifests/docs; never invented.

A missing or unreadable input stops the run naming exactly what is missing —
never proceed on memory or guesses.

## Planning check before init

Before init writes anything, classify the work against the story and any
spec it links:

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

## Sync

Sync is `raftkit-dev:docs` on an explicit change set; `implement` and `fix`
call it once on the final diff.
