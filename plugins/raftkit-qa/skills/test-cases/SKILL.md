---
name: test-cases
description: Turn one Asana story into test cases for the QA-owned Sheet and a numbered manual run sheet — "write test cases for this story", "make a run sheet". Cases keyed on the [AC] GID, expected results verbatim, QA edits win, rows handed back as CSV; one stop only to create a Sheet. Failures — bug.
user-invocable: true
---

# test-cases

Load `raftkit-core:rules` first unless it is already in this conversation.

- **Announce it** — `Using raftkit-qa:test-cases` in the first reply, once (`raftkit-core:rules`).

One story → its test cases for the project's QA Sheet, and a run sheet QA executes. Two stories are two runs.

**The rule:** the story is the only source. Every case traces to an `[AC]`, a scenario, an edge-case row or a permission boundary in the story. Never add behaviour, never drop an `[AC]`: what cannot be covered is named as a gap.

## Inputs

The story, and the Sheet the project's cases live in (QA names it once; one project per Sheet). None named → ask. No QA Sheet yet → offer to create `<project> QA` from a CSV upload in the folder QA names.

Drive cannot edit a Sheet in place, so no run appends to or updates an existing Sheet: its new rows and proposed updates come back as one `csv` block for QA to paste. In-place append stays off until the QA owner verifies it in Cowork.

## Run

1. **Read at once**: the story and all its subtasks, and every Sheet row carrying this story's `[AC]` GIDs. No `[AC]` subtasks → stop with the first line; `Development` not done → say the second and continue.

```output
Can't build a run sheet — the story has no [AC]s. Ask the PM to run raftkit-pm:story check.
Development not marked done; generating anyway.
```

2. **Derive the cases** per `references/format.md`: per `[AC]`, per scenario, per edge-case row (`N/A` rows kept as `N/A`), and one each for the allowed and the blocked actor. Expected results are the story's exact strings.
3. **Match by key.** A case whose key is new → append. A key already in the Sheet → keep QA's row; when the `[AC]` changed, show the proposed update beside it, applied only if QA names it. An `[AC]` gone from the story → listed; its row is never deleted.
4. **Name the gaps**: every `[AC]` with no runnable case, every edge-case row the `[AC]`s leave uncovered.
5. **Hand back** the run sheet, then the rows to append and the proposed updates as one `csv` block, naming the Sheet they belong to. That writes nothing, so there is no stop.
6. **No Sheet yet**: the Sheet's creation is the run's only write. Stop once with the run sheet, every row, the new Sheet's name and its folder.

```output
Run sheet: 27 steps covering 6 [AC]s — gaps: listed
- [AC] "export completes within 10 s" — no runnable step; the story gives no test data.
New Sheet "Riverside QA" in the folder QA named: 9 rows.
**STOP** — approve to write, edit to change, or decline.
```

7. **On go**: upload the CSV as the new Sheet; read back once and report the row count. Folder unreachable → name which account needs edit access; write nothing.

A failing step routes to `raftkit-qa:bug` with its number, action and expected result. This skill never files.
