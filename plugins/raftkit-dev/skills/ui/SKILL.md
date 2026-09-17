---
name: ui
description: Build a story's UI from its own designs and its exact copy — "build the UI for this story", "create the screens", "implement the UI phase", or a UI phase inside implement. Platform-correct through frontend-design and the project's stack, every state the story defines, nothing invented. Missing copy or an unreachable design stops that element, never the build.
user-invocable: true
---

# ui

One story's screens, built to what the story actually says. `raftkit-core:rules` apply. Called from an `implement` phase it takes the story, the phase and the engine check already in hand; standalone it fetches the story once.

**Nothing user-facing is invented.** Copy is used verbatim, designs are consumed, breakpoints and tokens come from the project. When the story is silent, ask; never fill the gap.

## Run

1. **Confirm there is UI to build.** No design and no copy in the story, or an explicit no-UI-scope note, means generate nothing and say so. That is a correct outcome.
2. **Pick the stack**: web goes to React and Next.js with the defaults in `references/web-defaults.md`; mobile goes to Expo with `references/recipe-native-ui-structure.md`. A story covering both reads its own parity note and builds each surface to its own conventions. Solved problems come from the recipes rather than being redesigned: `references/recipe-in-app-auto-update.md` and `references/recipe-review-at-happy-moment.md`.
3. **Build screen by screen**, delegating to `frontend-design:frontend-design`:
   - **Designs** — build to the linked frames. A layout described only in words is a constraint, not licence to embellish.
   - **Copy** — the story's exact strings, verbatim. No rewording, no tone edits, no placeholder.
   - **States** — every edge-case row the story fills for that screen: waiting, empty, error with its exact message and recovery, success, limits, defaults. A row marked not applicable is reported as considered, not built.
   - **Accessibility** — tap targets, keyboard flow, screen-reader labels and breakpoints are requirements. A native control keeps its built-in accessibility; never swap it for a look-alike that drops focus order or labels.
   - **Reuse first** — an existing component before a new one.
4. **Report coverage** per screen, so a reviewer can check it against the story: the states built, the components reused, the elements stopped.

## The two hard stops

**Missing copy** — stop that element, ask the PM for the exact string, naming the screen, the element and what the string is for, and keep building everything else. A placeholder that ships is a defect.

**Unreachable design** — name the exact link, stop that screen only, and continue the others. Never guess a layout, substitute a similar frame, or build from memory. An ambiguous design is treated like missing copy for the undefined parts.

## Resolution order

Project Profile beats the story, the story beats a recipe, a recipe beats a library default. The story is the ceiling: a recipe never adds behaviour the story did not ask for, and an optional polish pass never overrides the story's designs, its copy or the scope contract.

Design tokens are applied, never defined here. Backend and API work belong to the story's other phases.
