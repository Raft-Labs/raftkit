---
name: suite
description: Generate or re-sync a project's manual test-case suite in a QA-owned Google Sheet from the Project Profile — "generate the test suite", "build test cases for project X", "sync the QA sheet", "regenerate the suite". Two-way sync on stable case IDs, QA edits win, one stop before the Sheet write. Not for per-story steps (run-sheet) or bugs (bug).
user-invocable: true
---

# suite

Turn the approved Project Profile into a manual test-case suite QA edits directly in a Google Sheet, and keep the two in step. `raftkit-core:rules` apply.

**The guarantee:** a regeneration never silently overwrites what QA changed. Case IDs are the sync key; QA edits win; a generated change to a QA-touched row is shown as a conflict, never applied.

## Inputs

The project's Profile (found by the rules' convention) and where the Sheet lives (QA names it once; one project per Sheet). No Profile → stop; no Sheets connector in this session → stop and name it, never write anywhere else.

```output
No Project Profile found — run raftkit-pm:profile first, then re-run suite.
```


## Run

1. **Read everything at once**: the Profile and every doc it links, and the whole Sheet if one exists. No Sheet → first run.
2. **Generate** cases grouped by feature, each with steps, data, expected result, exactly one coverage tag, and a citation to the profile fact it comes from. A case with no tag or no citation is not emitted. Layout: `references/sheet.md`.
3. **First run** → the draft is the full Sheet. **Re-run** → diff by case ID into new / unchanged / delta on an untouched row / conflict on a QA-touched row (`references/sheet.md`).
4. **Stop once.** Show the additions, the deltas, and every conflict side by side. Conflicts resolve in one reply: "accept all generated except …" or "keep QA's on all except …" is enough. A reply that resolves every conflict is the go: write with those choices, no second stop; a reply that leaves one open re-presents. Past the soft cap, propose a split by feature area in the same message.

```output
Suite draft for <project> → <Sheet name>: 42 new, 3 deltas, 2 conflicts (both versions above).
Approve writes the new rows and deltas. Both conflicts keep QA's version unless you say "accept generated on …".
**STOP** — approve, edit to change, or decline.
```

5. **On go**, write in batches, then report the success line from `references/sheet.md`.

## Never

- Write a row QA touched without QA choosing it.
- Renumber or reuse a case ID; drop, rename or reorder a column.
- Merge two projects into one Sheet.
- Half-write on an access error: stop and name the exact fix (which account needs edit access to which Sheet).
