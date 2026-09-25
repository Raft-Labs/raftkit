---
name: suite
description: Generate or re-sync a project's manual test-case suite in a QA-owned Google Sheet from the Project Profile — "generate the test suite", "build test cases for project X", "sync the QA sheet", "regenerate the suite". Stable case IDs, QA edits win; a re-sync hands back changed rows as CSV. Not for per-story steps (run-sheet) or bugs (bug).
user-invocable: true
---

# suite

Turn the approved Project Profile into a manual test-case suite QA edits directly in a Google Sheet, and keep the two in step. Load `raftkit-core:rules` first unless it is already in this conversation.

**The guarantee:** a regeneration never silently overwrites what QA changed. Case IDs are the sync key; QA edits win; a generated change to a QA-touched row is shown as a conflict, never applied.

## Inputs

The project's Profile (found by the rules' convention) and where the Sheet lives (QA names it once; one project per Sheet). No Profile → stop.

```output
No Project Profile found — run raftkit-pm:profile first, then re-run suite.
```


## Run

1. **Read everything at once**: the Profile and every doc it links, and the whole Sheet if one exists. No Sheet → first run.
2. **Generate** cases grouped by feature, each with steps, data, expected result, exactly one coverage tag, and a citation to the profile fact it comes from. A case with no tag or no citation is not emitted. Layout: `references/sheet.md`.
3. **Re-run** → diff by case ID into new / unchanged / delta on an untouched row / conflict on a QA-touched row, then hand back per `references/sheet.md`: changed rows as CSV for QA to paste, conflicts side by side. Drive cannot edit a Sheet in place, so a re-run writes nothing and has no stop.
4. **First run → stop once** with the full draft and the new Sheet's name and folder. Past the soft cap, propose a split by feature area in the same message.

```output
Suite draft for <project> → new Sheet <Sheet name>: 42 cases across 6 features.
**STOP** — approve to create the Sheet, edit to change, or decline.
```

5. **On go**, create the Sheet, then report the success line from `references/sheet.md`.

## Never

- Write a row QA touched without QA choosing it.
- Renumber or reuse a case ID; drop, rename or reorder a column.
- Merge two projects into one Sheet.
- Half-write on an access error: stop and name the exact fix (which account needs edit access to which Sheet).

- **Announce it** — `Using raftkit-qa:suite` in the first reply, once (`raftkit-core:rules`).
