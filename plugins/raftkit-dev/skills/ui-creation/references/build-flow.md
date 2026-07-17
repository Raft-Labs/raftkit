# Build flow — screen by screen

How `ui-creation` turns one story's UI scope into built screens. The story's §7
(designs, copy, accessibility) and §6 (WEESLD) drive every step; this skill
orchestrates `frontend-design` + the stack pack + `recipes` and invents nothing
user-facing.

## Select the stack pack

- **Web story** → the React/Next.js stack pack; apply `recipes`'
  `recipe-native-ui-structure` web variant **by reference**.
- **Mobile story** → the Expo stack pack; apply `recipes`'
  `recipe-native-ui-structure` **by reference** — do not restate the recipe here,
  consult it.
- **Both surfaces** → read the story header's parity vs. divergence note and
  build each surface to its own conventions.

Web-stack defaults live in `recipes`' `web-defaults.md` — consult, do not copy.

## The no-UI-scope exit

Before building anything, confirm the story has UI to build. If §6's Empty row
says the story has no UI scope, or the story carries no §7 designs and no §7
copy, **generate nothing and state so plainly**. This is the story's Empty WEESLD
state for this skill — a clean, correct outcome, not a failure.

## The per-screen loop

For each screen in the story's UI scope:

1. **Designs.** If §7 links frames, build to them via `frontend-design`. If §7
   instead **describes the layout in words** (no frames), follow that description
   and the platform defaults — and add **no flourishes beyond the description**.
   A described layout is a constraint, not a licence to embellish.
2. **Copy.** Wire the story's exact §7 strings — labels, buttons, empty/error/
   success messages, verbatim. A needed string the story does not provide is
   **missing copy**: stop that element and route it to the PM per
   `guardrails.md`. Never fill the gap with a placeholder.
3. **WEESLD states.** Build every state the story defines for this screen (see
   below).
4. **Accessibility.** Build to the story's §7 accessibility notes — tap-target
   size, keyboard flow, screen-reader labels, breakpoints. They are requirements.
5. **Reuse first.** Reuse an existing component before creating a new one
   (story §11); create a new component only when nothing reusable fits.

## WEESLD coverage

Every populated §6 row is an element to build, and each screen reports which
states it covers (the story's §6 Success row asks for exactly this):

- **Waiting** — the loading / in-progress UI (spinners, optimistic state,
  disabled controls) as the story describes it.
- **Empty** — the first-time / no-data state. (At the story level, an empty UI
  scope triggers the no-UI-scope exit above.)
- **Error** — every failure the story lists, with its exact message and recovery.
  The unreachable-design-link failure is handled as a hard stop in
  `guardrails.md`.
- **Success** — the confirmation UI (toast / redirect / updated view) with the
  story's exact wording.
- **Limits** — min/max, lengths, counts, and the behaviour at the limit, per the
  story.
- **Default values** — pre-filled values and fallbacks from the story; platform
  defaults from `recipes`; theme from the repo's design tokens.

"N/A" in a §6 row is a valid answer — build only the states the story populates,
and report the coverage so a reviewer can check it against §6.

## Responsive & i18n

- **Responsive** behaviour per the story's §7 notes and breakpoints — no invented
  breakpoints.
- **i18n** per the story's rules: when the product is multi-language, user-facing
  strings are localized and never hardcoded; the story's exact strings are the
  source language. When the product is single-language, still keep strings out of
  logic per the stack pack's convention.

## What this flow never does

- Invent copy, designs, breakpoints, or brand.
- Define or change design tokens (it applies them).
- Do backend/API work, or generate a whole app at once — it works within the
  story's decomposition phases (story §6 Limits).
