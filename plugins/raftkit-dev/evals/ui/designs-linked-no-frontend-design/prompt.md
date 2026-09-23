---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-dev:ui standalone for the web story "Guest wishlist"
(task 1216770000000456). What the run reads, given here:

- Screens: the wishlist page, designed at https://www.figma.com/design/Wx12ab/Riverside?node-id=40-12 ;
  the heart button on the room card, designed at https://www.figma.com/design/Wx12ab/Riverside?node-id=40-30 ;
  and the sign-in prompt, described in words only: "a bottom sheet with the prompt and one Sign in button".
- Copy: heart button label "Save to wishlist"; empty wishlist "No saved rooms yet. Tap the heart on any room to save it.";
  sign-in prompt "Sign in to keep your wishlist on every device."; save error "We couldn't save that room. Try again."
- Edge-case rows: empty (copy above); error (copy above, recovery: retry); waiting N/A.
- Project Profile: the visual system lives in `packages/ui/tokens.ts`.

Eval harness: this session has no Figma connector and no write or shell tools.
Report the build plan and the coverage per screen the way the skill reports it;
write no files.
