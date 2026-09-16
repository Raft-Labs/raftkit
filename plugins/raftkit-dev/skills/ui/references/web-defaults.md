# Web-stack defaults

RaftLabs' standard web-stack decisions, so a web story does not re-argue settled
choices. `implement` consults these when planning a web story.

**Two tiers below.** *House law* is derivable from RaftLabs' stated stack and
PRD-level house rules — treat it as the default. *Default-with-override* is a
sensible starting point that no single source fixes as law — apply it, but it is
the first thing a Project Profile is expected to override.

**Every entry is overridable** via an explicit Project Profile entry, and only
that way (silent per-repo divergence is not allowed). When a project overrides a
default, the override wins and the **deviation is noted in the plan**.

## House law (from the RaftLabs stack)

| Decision | Default | Why |
|---|---|---|
| Web framework | React with **Next.js** | The RaftLabs web stack |
| Backend runtime | **Node.js** | The RaftLabs backend stack |
| Hosting / compute | **AWS Serverless** | The RaftLabs delivery model |

## Default-with-override (starting points, not fixed law)

These are reasonable defaults so a story need not decide them, but no source
settles them — expect a Project Profile to override per project.

| Decision | Default starting point | Override via |
|---|---|---|
| Rendering strategy (SSR / SSG / client) | Choose per route from the story's needs; default to server components where Next.js makes them the low-friction choice | Project Profile |
| Data access | A single typed data layer; no ad-hoc fetches scattered through components | Project Profile |
| Auth pattern | Server-enforced (never UI-only gating), matching the project's chosen provider | Project Profile |
| Styling | The project's design tokens style the UI; recipes define structure, not brand | Project Profile |
| Language | **TypeScript** across the codebase | Project Profile |
| Localization | User-facing strings localized, not hardcoded; the story's exact strings are the source language | Project Profile |

## Named libraries (the layer below)

The tables above deliberately name no libraries — a form-validation package, a
data-fetching client, a styling kit. Those choices do exist in writing: the
`docs` skill's archetype recipes record the stacks RaftLabs' reference
implementations actually run on, named library by library, in
[stack-and-domain-recipes.md](../../docs/references/stack-and-domain-recipes.md).
Archetype A additionally pins exact versions in a catalog; the others still name
major versions. Every version there goes stale — check it before adopting.

Treat that file as the **named-library layer**: the starting point when a web
story needs a library this file leaves open, so the story does not re-argue a
choice the reference projects already made. Read the archetype that matches the
project, not the whole file, and note in the plan when the project departs from
it.

Two limits on that, because those archetypes describe whole projects rather than
libraries alone:

- **House law above is not up for archetype override.** Some archetypes there run
  Vite instead of Next.js, or host somewhere other than AWS Serverless. Those are
  descriptions of specific reference projects, not permission to change the three
  House law rows — a departure from House law needs a Project Profile entry, same
  as any other override.
- **The resolution order is unchanged.** This layer sits at the bottom of it;
  `recipes`' own [SKILL.md](../SKILL.md) owns that order.

If a decision is covered in neither place and no source states it, decide it for
the story at hand and, if it looks reusable, **propose it as a default by PR** —
do not silently bake an invented specific in as house law.
