---
name: bug
description: File a bug into Asana from a Jam recording or retest a returned fix — "file a bug", "log this Jam as a bug", "raise a defect for this failing step", "retest this bug", "did the fix hold". Quotes evidence verbatim, proposes the judgment fields, stops once before the write. Fixing — raftkit-dev:fix.
user-invocable: true
---

# bug

Load `raftkit-core:rules` first unless it is already in this conversation. A recording or a failing step → **file**; a bug handed back with a fix → **retest**.

- **Announce it** — `Using raftkit-qa:bug` in the first reply, once (`raftkit-core:rules`).

## File

1. **Read at once**, once a target story is named: the Bugs Template, the story with its `Bugs` subtask, and the Jam (events, console, network; frames only for a visual defect). No Jam → the template's next evidence tier, marked, every environment field asked of QA. No `Bugs` subtask → propose it in the same go.
2. **Pre-fill from evidence**: environment, steps from a clean start, actual result with console and network errors **verbatim** (a redacted secret is marked). Never invent device or console data. Two defects → two drafts.
3. **Propose the judgment fields**, each `proposed — edit inline`: severity, priority, reproducibility, expected result (quoted from the story), `Done when` (one checkable line per item). A field the evidence does not support, and always `Done when`, is `⚠️ assumed until confirmed` and blocks the write.
4. **Title**: `[Platform][Severity] what + where`.
5. **Stop once** with the draft, its target (a subtask under the story's `Bugs` subtask) and the priority tag's exact name, looked up, never created. Open `⚠️` fields sit above the stop line; a go that leaves one open is an edit.
6. **On go**: create, read back once, then:

```output
Filed under <story> · Bugs — <bug link>, tier <tier> — apply tag <name> by hand.
```

## Retest

1. **One bug per run**; none named → ask. Read it once and check its two gates first (`Fixed in build: pending — first build containing PR #<n>` counts as empty); either failing ends the run:

```output
Can't retest — no build to test against. Fill "Fixed in build ___" or name it in the hand-back, then hand it back.
Can't retest — this bug has no "Done when" checklist. Add it in file mode, then retest.
```

2. **Pass list**: every `Done when` item plus every adjacent flow the bug names, on the stated build and environment only:

```output
Can't retest — build <build> isn't available in <environment>.
```

3. **Show it as one table.** QA returns pass or fail with evidence per item, or a retest Jam.
4. **Stop once** with the pass comment, or the fail comment (fresh evidence verbatim, each failure tied to it) and the retest-failed tag's name. After it lands:

```output
Retest passed — all N done-when items + M regression checks green on build X. Close the bug.
Retest Failed — K of N+M items red on build X, returned to dev — apply tag <name> by hand.
```

The skill never closes a bug. Asana tagging is unverified in Cowork: QA applies every tag by hand. The stop line for both modes:

```output
**STOP** — approve to push, edit to change, or decline.
```
