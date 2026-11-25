---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-dev:ui standalone for the web story "Guest wishlist"
(task 1216770000000456). What the run reads, given here:

- Screens, described in words: the wishlist page, "a grid of saved room cards";
  the heart button on the room card, "an outline heart that fills when saved";
  the sign-in prompt, "a bottom sheet with the prompt and one Sign in button".
- Copy: heart button label "Save to wishlist"; empty wishlist "No saved rooms yet. Tap the heart on any room to save it.";
  sign-in prompt "Sign in to keep your wishlist on every device."
- Edge-case rows: empty (copy above); error — the heart save fails, recovery: retry, message not given; waiting N/A.
- Project Profile: the visual system lives in `packages/ui/tokens.ts`.

Eval harness: this session has no write or shell tools. Report the build plan
and the coverage per screen the way the skill reports it; write no files.
