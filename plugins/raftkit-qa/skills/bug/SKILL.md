---
name: bug
description: File a bug into Asana from a Jam recording or retest a returned fix — "file a bug", "log this Jam as a bug", "raise a defect for this failing step", "retest this bug", "did the fix hold". Reads the live Bugs Template once per chat, quotes evidence verbatim, proposes the judgment fields, stops once before the write. Fixing: raftkit-dev:fix.
user-invocable: true
---

# bug

Two modes on one bug lifecycle. `raftkit-core:rules` apply. Mode is decided by the ask: a recording or a failing step → **file**; a bug handed back with a fix → **retest**.

## File

1. **Validate, then read at once.** No target story → ask; a bug never floats free. Then in one turn: the Bugs Template (skip if already in this chat), the story with its `Bugs` subtask and the project's tags, and the Jam recording (metadata, events, console, network, screenshots). No Jam → the next evidence tier the template lists, marked as such, with the manual environment block required.
2. **Pre-fill from evidence** per `references/filing.md`: environment, steps from a clean start, actual result with console and network errors quoted verbatim. Two unrelated defects in one recording → two drafts in the same message.
3. **Propose the judgment fields** rather than asking them one at a time: severity, priority, reproducibility, expected result and the `Done when` checklist, each marked `proposed — edit inline`; a proposal the evidence does not support is marked `⚠️ assumed until confirmed` and blocks the write until QA confirms it. An odd severity/priority pair is flagged, not blocked.
4. **Self-check** the draft against the template and the checklist in `references/filing.md`; the title is `[Platform][Severity] what + where`.
5. **Stop once** with the full draft, its target (a new subtask under the story's `Bugs` subtask) and the priority tag to apply (resolved from the project; none → ask in the same message).
6. **On go**: create, tag, read back once, one line: `filed under <story> · Bugs, tier ⭐, checklist complete.`

## Retest

1. **Validate before fetching.** `Fixed in build ___` empty → `Can't retest — "Fixed in build ___" is empty. Fill the build and hand it back.` No `Done when` checklist → `Can't retest — this bug has no "Done when" checklist. Add it in file mode, then retest.` Then read the bug once (template from this chat if present).
2. **Build the pass list** per `references/retest.md`: every `Done when` item plus every adjacent flow the bug names. Retest on the stated build in the stated environment; unavailable → `Can't retest — build <build> isn't available in <environment>.` Never substitute a build.
3. **Walk every item**, recording pass/fail and fresh evidence.
4. **Stop once** with either the close comment, or the fail comment (fresh evidence quoted verbatim, failures itemised) plus the `Retest Failed` tag (create-or-ask, never silent). Only QA closes.

The stop line for both modes:

```output
**STOP** — approve to push, edit to change, or decline.
```
