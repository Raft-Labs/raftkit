---
type: llm
weight: 1
---

# Criteria

The design-skill check, the named link, the verbatim copy and the absent stop
are this case's regex and tool graders. Score 1 only if ALL hold, else 0:

1. Both Figma-linked screens are stopped by name with their exact links — the
   frames cannot be reached from this session — and the build carries on with
   the sign-in prompt. No stopped screen gets a guessed layout, a similar
   frame, or one built from memory.
2. The sign-in prompt is built to its words — a bottom sheet with the prompt
   and one Sign in button — and nothing more.
3. The states belonging to a stopped screen (empty, save error) are reported
   with that screen as stopped, not built on a guessed layout; the waiting row
   is reported as considered and not applicable.
4. Tokens come from `packages/ui/tokens.ts`; none are defined here.
5. Coverage is reported per screen: states built, components reused, elements
   stopped.
