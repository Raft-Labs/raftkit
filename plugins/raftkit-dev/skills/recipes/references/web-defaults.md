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
| Language | **TypeScript** across the codebase | Type safety is a house standard, not a per-project call |
| Backend runtime | **Node.js** | The RaftLabs backend stack |
| Hosting / compute | **AWS Serverless** | The RaftLabs delivery model |
| Localization | User-facing strings are **localized, never hardcoded** | House rule — the story's exact strings are the source language |

## Default-with-override (starting points, not fixed law)

These are reasonable defaults so a story need not decide them, but no source
settles them — expect a Project Profile to override per project.

| Decision | Default starting point | Override via |
|---|---|---|
| Rendering strategy (SSR / SSG / client) | Choose per route from the story's needs; default to server components where Next.js makes them the low-friction choice | Project Profile |
| Data access | A single typed data layer; no ad-hoc fetches scattered through components | Project Profile |
| Auth pattern | Server-enforced (never UI-only gating), matching the project's chosen provider | Project Profile |
| Styling | The project's design tokens style the UI; recipes define structure, not brand | Project Profile |

If a decision is not covered here and no source states it, decide it for the story
at hand and, if it looks reusable, **propose it as a default by PR** — do not
silently bake an invented specific in as house law.
