# Generation — adaptive, never forced

Generation materializes the confirmed design into documentation using the
adaptable templates in `assets/templates/` through progressive disclosure:
the structure is recommended, never imposed. The repository's own conventions
always win.

## The three postures

- **Greenfield** — no docs exist: recommend and generate the complete default
  structure — foundation docs (tech stack, architecture overview with its
  diagrams, decisions/ADR seam, glossary, design guidelines, NFR, RBAC
  matrix, changelog + changes-log), one folder per module (module overview,
  features, APIs, schemas, workflows, state machines and async jobs where
  applicable, observability, compliance where applicable, test plan), shared
  cross-cuts, index registries, and the root CLAUDE.md and README. Every file
  comes from its template, filled from the confirmed design — placeholders
  are completed or explicitly marked, never silently dropped.
- **Existing living docs** — the discovered convention is the yardstick: map
  each applicable document capability onto the repository's own structure,
  naming, and history convention; generate only what the design session
  produced and the convention accommodates; restructure nothing.
- **Hybrid** — existing docs plus missing capabilities: additions land only
  through an approved proposal (exact paths + content shown first); a hybrid
  never silently reshapes what already exists.

## Rules

- Nothing is generated before the Phase-8 sign-off; ambiguity in where a
  capability should land is asked, never guessed.
- Code samples always match the chosen archetype — never mixed.
- Diagrams follow `diagram-catalog.md`: generated when applicable, recorded as
  `N/A — <reason>` when not.
- Generated docs carry the repository's own history convention (frontmatter
  version tables or verification footers — whichever the convention uses).
- Stories and bugs are not generated here: drafting routes to
  `raftkit-pm:story`, filing to `raftkit-qa:bug`.
- After generation, verification (Phase 10) runs before the set is called
  done, and `raftkit-dev:docs` owns every later sync.
