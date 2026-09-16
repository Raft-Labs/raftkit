---
name: bug
description: File a bug into Asana from a Jam recording or retest a returned fix — "file a bug", "log this Jam as a bug", "raise a defect for this failing step", "retest this bug", "did the fix hold". Reads the live Bugs Template once per chat, quotes evidence verbatim, proposes the judgment fields, stops once before the write. Fixing: raftkit-dev:fix.
user-invocable: true
---

# bug

Two modes, one bug lifecycle. `raftkit-core:rules` apply. A recording or a failing step → **file**; a bug handed back with a fix → **retest**.

## File

1. **Validate, then read at once.** No target story → ask; a bug never floats free. Then in one turn: the Bugs Template (skip if already in this chat), the story with its `Bugs` subtask and the project's tags, and the Jam recording (metadata, events, console, network, screenshots). No Jam → the next tier the template lists, marked, with the manual environment block required. No `Bugs` subtask → propose creating it in the same go.
2. **Pre-fill from evidence** per `references/filing.md`: environment, steps from a clean start, actual result with console and network errors verbatim. Two unrelated defects in one recording → two drafts in one message.
3. **Propose the judgment fields** instead of asking them one at a time: severity, priority, reproducibility, expected result, `Done when`, each `proposed — edit inline`; one the evidence does not support is `⚠️ assumed until confirmed` and blocks the write. An odd severity/priority pair is flagged, not blocked.
4. **Self-check** against the template and the checklist in `references/filing.md`; the title is `[Platform][Severity] what + where`.
5. **Stop once** with the full draft, its target (a new subtask under the story's `Bugs` subtask) and the priority tag (resolved from the project; none → ask in the same message). Every `⚠️` field and open checklist question sits directly above the stop line; a go that does not answer them is an edit.
6. **On go**: create, tag, read back once, then:

```output
Filed under <story> · Bugs — <bug link>, tier <tier>, checklist complete.
```


## Retest

1. **One bug per run**; none named → ask, never guess. Read the bug once (no template needed; it carries its own labels). Before any other fetch, check its two gates; either failing ends the run:

```output
Can't retest — "Fixed in build ___" is empty. Fill the build and hand it back.
Can't retest — this bug has no "Done when" checklist. Add it in file mode, then retest.
```

2. **Build the pass list** per `references/retest.md`: every `Done when` item plus every adjacent flow the bug names. The stated build, the stated environment, never a substitute.

```output
Can't retest — build <build> isn't available in <environment>.
```

3. **Show the pass list as one table.** QA returns pass/fail and evidence for every item in one reply, or a retest Jam link the skill reads.
4. **Stop once** with the pass comment, or the fail comment (fresh evidence verbatim, failures itemised) plus the `Retest Failed` tag (create-or-ask in the same message). The skill never marks a bug complete; QA does.

The stop line for both modes:

```output
**STOP** — approve to push, edit to change, or decline.
```
