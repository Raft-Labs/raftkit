---
type: llm
weight: 1
---

# Criteria

The fixed lines, the verbatim expected string and the absent stop are this
case's regex graders. Score 1 only if ALL hold, else 0:

1. Every step names a start state, one action and one checkable result; no
   "verify it works" or "check the page".
2. Groups cover each runnable `[AC]`, the error and waiting rows, the empty row
   recorded as N/A, and one group each for the allowed guest and the blocked
   empty-cart guest.
3. The decline-code `[AC]` is named as a gap (the story gives no way to see the
   log), and no step invents behaviour, copy or data the story does not state.
4. The rows to append are keyed on the given `[AC]` GIDs (or the story GID for
   a case no `[AC]` covers); no key is invented.
5. Nothing is claimed as written: the rows come back as one `csv` block for
   QA to paste into the existing Sheet.
