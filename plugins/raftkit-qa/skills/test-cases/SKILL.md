---
name: test-cases
description: Turn one Asana story into test cases in the QA-owned Sheet and a numbered manual run sheet — "write test cases for this story", "make a run sheet", "add this story to the QA sheet". Cases keyed on the [AC] GID, expected results quoted verbatim, QA edits win, one stop before the Sheet write. Failures — bug.
user-invocable: true
---

# test-cases

One story → its test cases appended to the project's QA Sheet, and a run sheet QA executes. Two stories are two runs. Load `raftkit-core:rules` first unless it is already in this conversation.

**The rule:** the story is the only source. Every case traces to an `[AC]`, a scenario, an edge-case row or a permission boundary in the story. Never add behaviour, never drop an `[AC]`: what cannot be covered is named as a gap.

## Inputs

The story, and the Sheet the project's cases live in (QA names it once; one project per Sheet). None named → ask.

## Run

1. **Read at once**: the story and all its subtasks, and every Sheet row carrying this story's `[AC]` GIDs. No `[AC]` subtasks → stop with the first line; `Development` not done → say the second and continue.

```output
Can't build a run sheet — the story has no [AC]s. Ask the PM to run raftkit-pm:story check.
Development not marked done; generating anyway.
```

2. **Derive the cases** per `references/format.md`: per `[AC]`, per scenario, per edge-case row (`N/A` rows kept as `N/A`), and one each for the allowed and the blocked actor. Expected results are the story's exact strings.
3. **Match by key.** A case whose key is new → append. A key already in the Sheet → keep QA's row; when the `[AC]` changed, show the proposed update beside it, applied only if QA names it. An `[AC]` gone from the story → listed; its row is never deleted.
4. **Name the gaps**: every `[AC]` with no runnable case, every edge-case row the `[AC]`s leave uncovered.
5. **Stop once** with the run sheet, the rows to append, the proposed updates and the Sheet's name.

```output
Run sheet: 27 steps covering 6 [AC]s — gaps: listed
- [AC] "export completes within 10 s" — no runnable step; the story gives no test data.
Sheet "Riverside QA": 9 rows to append, 1 update proposed.
**STOP** — approve to write, edit to change, or decline.
```

6. **On go**: append the rows and apply the named updates; read back once and report the counts. Sheet unreachable → name which account needs edit access; write nothing. Sheets append unverified in Cowork: if no tool can append, hand the rows back as one `csv` block for QA to paste.

A failing step routes to `raftkit-qa:bug` with its number, action and expected result. This skill never files.

- **Announce it** — `Using raftkit-qa:test-cases` in the first reply, once (`raftkit-core:rules`).
