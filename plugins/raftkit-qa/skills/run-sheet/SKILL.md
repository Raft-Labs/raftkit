---
name: run-sheet
description: Turn one Asana story into a numbered manual run sheet — "make a run sheet for this story", "turn this story into test steps", "generate the manual test run for task X". Steps derive from the story's scenarios and every [AC], expected results quote the story verbatim, gaps are named. Writes nothing. Project-wide suite: suite. Filing a failure: bug.
user-invocable: true
---

# run-sheet

One story → an executable, deterministic run sheet. `raftkit-core:rules` apply.

**The rule:** the story is the only source. Every step traces to a scenario, an `[AC]`, an edge-case row or a permission boundary already in the story. The sheet never adds behaviour and never drops an `[AC]`: what it cannot cover, it names.

## Run

1. **Validate before fetching.** No story named → ask. Then fetch the story and all its subtasks once. No `[AC]` subtasks → stop: `Can't build a run sheet — the story has no [AC]s. Ask the PM to run raftkit-pm:story check.` `Development` not done → one line, `Development not marked done; generating anyway`, and continue.
2. **Reuse the suite if it is cheap.** If the project's suite Sheet is already in context or reachable in one read, pull the cases covering this story by case ID (same ID, no new number). Otherwise generate standalone and say the slice is missing. The suite is never a precondition.
3. **Derive the steps** per `references/format.md`: one group per scenario, per `[AC]`, per edge-case row the story specifies (`N/A` rows recorded as `N/A`), and one group each for the allowed and the blocked actor. Expected results are the story's exact strings.
4. **Name the gaps**: every `[AC]` with no runnable step, every edge-case row the `[AC]`s leave uncovered.
5. **Deliver** the numbered table in chat with the success line. This skill writes nothing; when QA wants it in a run-sheet tab, that write is its own one-line ask and never touches the suite Sheet's case rows.

A failing step routes to `raftkit-qa:bug` with its number, action and expected result attached. This skill never files.

```output
Run sheet: 27 steps covering 6 [AC]s — gaps: listed
- [AC] "export completes within 10 s" — no runnable step; the story gives no test data.
```
