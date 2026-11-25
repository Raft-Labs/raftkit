---
type: llm
weight: 1
---

# Criteria

The verbatim copy and the absent stop are this case's regex graders. Score 1
only if ALL hold, else 0:

1. The save-error message is stopped: the reply asks the PM for the exact
   string, naming the screen (the room card's heart button), the element (the
   save-error message) and what the string is for.
2. No placeholder, invented or reworded error text appears for that element.
3. Everything else is still planned: the wishlist page, the heart button, the
   sign-in prompt and the empty state, each to the story's words.
4. Tokens come from `packages/ui/tokens.ts`; none are defined here.
5. Coverage is reported per screen: states built, components reused, elements
   stopped.
