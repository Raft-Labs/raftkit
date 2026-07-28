---
name: ui-creation
description: This skill should be used when a RaftLabs developer builds the UI for a story that has UI scope — e.g. "build the UI for this story", "create the screens", "implement the UI phase", or when /implement reaches a UI phase. It orchestrates the frontend-design plugin plus the project's stack pack (web = React/Next.js, mobile = Expo) and RaftKit's recipes skill to produce platform-correct interfaces from the story's own designs and its exact copy — never inventing user-facing text, never guessing an unreachable design, building every WEESLD state, and honouring the story's accessibility notes. It builds UI only; design creation, backend/API work, and design-token definition are out of scope.
user-invocable: true
---

# ui-creation

Build the UI for one story so it comes out platform-correct and consistent —
matching the story's own designs, using the story's exact copy, and dropping in
RaftLabs' solved-once defaults instead of re-deciding them per screen.

This skill **orchestrates** three engines and rebuilds none of them: the
`frontend-design` plugin (design-faithful UI), the project's **stack pack**
(web = React/Next.js, mobile = Expo), and RaftKit's `recipes` skill (platform
structure defaults + the resolution order). It generates no brand, defines no
design tokens, and ships no component library — it consumes what the story and
the project already provide.

The story is the spec. Its §7 (designs, copy, accessibility) and §6 (WEESLD)
are the source of truth; nothing user-facing is invented here.

## The rules that govern everything

Four hard rules, all non-negotiable. The first two are the ones that most often
tempt a shortcut — they are **hard stops**, detailed in
`references/guardrails.md`.

1. **Copy is the story's, verbatim.** User-facing text comes from the story's
   exact strings. A string the story does not provide is **missing copy**: stop
   that element, route the exact string request back to the PM, and ship **no
   placeholder** — an invented or lorem string is a defect.
2. **Designs are consumed, never invented.** Build to the linked frames. If a
   design link is **unreachable**, name the exact link, stop **only that screen**,
   keep building the others, and never guess the design.
3. **Every WEESLD state in the story is built.** Each populated §6 row (Waiting,
   Empty, Error, Success, Limits, Default values) is an element to build and to
   report coverage for. See `references/build-flow.md`.
4. **Accessibility notes are requirements.** The story's §7 accessibility notes
   are built to, not treated as suggestions.

## Preconditions

- `raftkit-core` is installed (this skill obeys `workflow-constants`,
  `house-rules`, `write-protocol`); the `recipes` skill and the project's stack
  pack are available. The implementation provider is
  `frontend-design:frontend-design` (the plugin's only component) — its
  readiness, like every provider's here, is `raftkit-dev:capability-preflight`'s
  call. If a required capability is missing, stop with the preflight's report —
  do not substitute. Adoption policy for the audit/browser/mobile providers is
  in `references/guardrails.md`.
- **A story with UI scope.** From `/implement` the story and phase are in hand;
  standalone, take the task link/GID. Read the story **live** via the Asana
  connector every run (GIDs from `workflow-constants`) — never from memory or
  this repo.
- **No UI scope → exit stating so.** If the story has no UI to build (its §6
  Empty row, or no §7 designs/copy at all), generate nothing and say so plainly.
  That is a clean, correct outcome, not a failure.

## Run flow

1. **Read the story live and scope the UI.** Pull §7 (designs, copy,
   accessibility), §6 (WEESLD), and any layout description. Confirm the story has
   UI scope; if not, exit stating so.
2. **Select the stack pack.** Web story → React/Next.js; mobile story → Expo.
   A story may name both surfaces (note parity vs. divergence from the header).
3. **Resolve defaults** through the resolution order below before building, so a
   Project Profile override is applied and **noted in the plan**, and any
   story-vs-recipe clash is surfaced.
4. **Build screen by screen** per `references/build-flow.md`: for each screen,
   consume its designs (or its written layout, without invented flourishes), wire
   the story's exact copy, build each WEESLD state the story defines, and honour
   the accessibility notes. Mobile screens apply `recipes`' native-UI-structure
   defaults **by reference**. Reuse existing components before creating new ones.
5. **Let the guardrails fire as hard stops** (`references/guardrails.md`): missing
   copy stops that element and routes the string to the PM; an unreachable design
   link stops that screen only.
6. **Report** what was built: the screens, the WEESLD states each one covers, any
   element stopped for missing copy (with the exact string request for the PM),
   any screen stopped for an unreachable link (named), and any Project Profile
   override applied.

## Resolution order (matches `recipes` — highest wins)

Do not restate the recipes' content; apply this order over it.

1. **Project Profile override** — a project may override a default or a recipe
   **choice only**, through an explicit Profile entry. When one applies, it wins
   and the **deviation is noted in the plan**. A Profile **never** overrides an
   explicit story requirement or `[AC]`; if a Profile entry contradicts the
   story, the **story wins** and the clash is surfaced like a story-vs-recipe
   conflict. (The Project Profile home is owned by onboarding/core — reference it
   abstractly; never hardcode a path.)
2. **The story's explicit requirements** — on a **direct conflict between the
   story and a recipe/default, the STORY wins**. Surface the conflict to the PM
   as a possible recipe update (correctable by PR), never silently.
3. **The recipe / default itself** (`recipes` skill), as the fallback when
   nothing above speaks.

## Guardrails

- **No invented copy** — missing copy stops the element and routes the exact
  string to the PM; no placeholder ships (`references/guardrails.md`).
- **No guessed designs** — an unreachable design link is named, that screen is
  stopped, the others continue; the design is never guessed.
- **Every WEESLD state built** — coverage is reported per screen.
- **Accessibility notes are requirements** — built to, not skipped.
- **Component reuse before new components**; responsive behaviour per the story's
  §7 notes; i18n per the story's rules — user-facing strings localized, never
  hardcoded, when the product is multi-language.
- **Escalate to founders** per `house-rules` if UI work implies a budget,
  contract, or client-relationship decision beyond the story.

## Out of scope

- **Design creation** — designers own the frames; this skill consumes them.
- **Backend / API work** — other phases own it.
- **Brand systems / design-token definition** — the project's tokens style the
  UI; this skill applies them, it does not define them.
- **A shared component library or store-submission automation** — recipes are
  patterns, not packages (`recipes` skill).

## Reference files

- `references/build-flow.md` — stack-pack selection, the per-screen build loop,
  WEESLD coverage and the no-UI-scope exit, the described-layout branch, and the
  component-reuse / responsive / i18n rules.
- `references/guardrails.md` — the two hard stops (missing copy; unreachable
  design link) with their exact behaviour, plus the copy-is-exact and
  accessibility-is-a-requirement rules.
