---
name: docs-companion
description: Project-local documentation companion. Keeps this repository's docs and code in step without adding a stop - a one-line drift note at session start, the module doc read before its code changes, and docs parity through raftkit-dev:docs on the final diff. Activates when the repository has living project documentation or a docs/ tree the team keeps current.
---

# docs-companion

This project-local skill keeps the docs in step with the code in the
repository it is installed in. It is built and installed by the raftkit-docs
plugin. It never pauses a run: the only stop is the one before something
leaves the session.

## Session start

On the first substantive message of a session (and after a branch change),
locate the project docs tree, read the root instruction file, and compare its
claims with the repository. Report drift in one line only when there is some,
then carry on with the request. In a repo with code but no docs, name
`raftkit-docs:docs-product` once as the way to reverse-engineer them.

## Before a code change

The Asana story is the scope contract; its `[AC]`s define done. Read the
module doc that owns the code before changing it, so the change fits what is
documented. A disagreement between doc and story goes in the run's report.

## After a code change

Docs parity is `raftkit-dev:docs`: `implement` and `fix` run it once on the
final diff, and "sync the docs" runs it on its own. It maps each changed file
to the docs that own it and reports the outcome. This skill adds no check of
its own.

## Boundaries

- Never write outside this repository; never touch secrets or decrypt env
  files; never print secret values.
- Never write to project-management systems directly; the owning RaftKit
  skill drafts the write and stops once before it.
- The docs tree's own conventions always win over any structure this skill
  would prefer.
- **Plain English out** — every line a human reads is short, active-voice,
  and free of filler; a house term gets its one-line gloss on first use.
