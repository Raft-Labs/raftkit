# Guardrails — the two hard stops

These are the failures the story calls out as most important (§6 Error). Each is
a **hard stop with exact behaviour** — not a warning, not a best-effort. A shipped
placeholder or a guessed design is a defect, not a smaller build.

## Missing copy → stop the element, route to the PM, no placeholder

User-facing text comes from the story's exact §7 strings. When a screen needs a
string the story does not provide:

1. **Stop that element.** Do not build it with a stand-in. Do not use lorem
   ipsum, a paraphrase, a guessed label, or a "TODO" string. A placeholder that
   ships is a defect.
2. **Route the exact string request to the PM.** State precisely which string is
   missing — the screen, the element, and what the string is for (e.g. the empty
   state's message, the submit button's label) — so the PM can supply the exact
   copy. This is a request for the *exact* text, not an invitation to approve an
   invented one.
3. **Keep building the rest.** Only the element that needs the missing string is
   stopped; the screen's other elements and the story's other screens continue.

Copy that *is* present is used **verbatim** — no rewording, no tone edits, no
"improvements". Rewriting the story's copy is the same defect as inventing it.

## Unreachable design link → name it, stop that screen only

Designs are consumed, never invented. When a §7 design link cannot be reached
(dead link, no access, wrong URL):

1. **Name the exact link.** Report the specific unreachable link — not a vague
   "a design was missing" — so it can be fixed at the source.
2. **Stop only that screen.** Do not guess the design, do not substitute a
   similar frame, do not build to a remembered layout. That screen is stopped
   pending a reachable link.
3. **Continue the other screens.** One unreachable link stops one screen; the
   rest of the story's UI proceeds. A single broken link never halts the whole
   build.

A design link that resolves but is ambiguous or incomplete is treated the same
way as missing copy for the undefined parts: stop that element and route the
question to the PM rather than guessing.

## Accessibility notes are requirements

The story's §7 accessibility notes — tap-target size, keyboard flow,
screen-reader labels, breakpoints — are built to, not deferred. When the build
uses native controls (mobile, per `recipes`), preserve their built-in
accessibility; do not replace an accessible native control with a custom
look-alike that drops screen-reader support, focus order, or minimum tap-target
size.

## Provider adoption policy — adopted is required, unadopted is noted

Conditional providers around the build (the `impeccable:impeccable` audit/polish
skill, browser validation, the Expo stack pack) follow one policy, with
readiness always reported through `raftkit-dev:capability-preflight`:

- **Not adopted by the project** → the state is optional-not-selected; proceed
  and say so with an explicit note — no silent omission.
- **Adopted by the project/Profile or required by the story** → readiness is
  REQUIRED. Missing or installed-but-disabled reports through the preflight and
  the flow stops/asks per its policy. **Never silently continue without an
  adopted provider,** never silently enable or install one, never substitute
  something else.
- **Browser validation** runs only when the story's ACs are browser-visible.
- **The Impeccable audit, when it runs,** is post-implementation polish at most
  once per build — it may not override the story's designs, its exact copy, the
  Project Profile's tokens, or the scope contract. The story stays the spec.

## Why these are hard stops

At AI velocity the tempting failure is to keep momentum by filling a gap — a
plausible label here, a guessed layout there. Those gaps are exactly where a UI
drifts from what the client approved. Stopping the affected element and routing
the precise question back is slower for one screen and correct for the product;
guessing is faster and wrong. The story is the contract — when it is silent, the
answer is to ask, never to invent.
