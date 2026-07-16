---
name: test-run-sheet
description: This skill should be used when RaftLabs QA wants a numbered manual run sheet generated from one Asana story so they can execute exactly what the story promised — e.g. "make a run sheet for this story", "turn this story into test steps", "generate the manual test run for task X", "give me the execution steps with test data and expected results". Reads the story and its subtasks live from Asana, derives numbered steps from its Gherkin scenarios and every [AC], covers every WEESLD state and permission boundary, and flags anything the story leaves uncovered. For the project-level living suite use test-suite; to file a failing step as a bug use file-bug; to check a story is ready before testing use raftkit-pm story-readiness.
user-invocable: true
---

# test-run-sheet

Turn one story into an **executable manual run sheet**: a numbered list of
deterministic steps derived from the story's own Gherkin scenarios and `[AC]`
subtasks, each step naming its start state, action, test data, and expected
result. What QA tests is then exactly what the story promised — including every
edge state — because the sheet is generated *from the story*, not written beside
it.

This is v1's QA execution guide (PRD §5.4): guided manual testing is the depth
this version ships, and this sheet is the guide. The `[AC]`s map 1:1 to tests;
this skill makes that mapping runnable.

## The one rule that governs everything

**The story is the only source of truth; the sheet adds structure, never new
requirements.** Every step traces to a Gherkin scenario, an `[AC]`, or a WEESLD /
permission row *already in the story*. The sheet never invents behaviour the story
does not state, and it never drops an `[AC]` — an unmapped `[AC]` or an uncovered
WEESLD state is **flagged**, not silently omitted (a run sheet that quietly skips a
criterion tests less than the story promised, which is the one failure this skill
exists to prevent).

Two corollaries, both non-negotiable:

- **Expected results quote the story's exact strings** — verbatim, never
  paraphrased, because a paraphrase is a different assertion (the exact-strings
  rule is defined in full in `references/run-sheet-format.md`).
- **One story per run sheet** — the story's own stated limit; never merge two
  stories into one sheet.

## Inputs

1. **A target story** — a task link or GID. If none is given, **stop and ask**;
   never generate a run sheet for an unnamed story.
2. Nothing else is required. The step content comes from the story itself; the
   optional project suite (below) is reused where it exists but is never a
   precondition.

## Preconditions — check before generating

1. **Resolve the workspace GID** from `raftkit-core/workflow-constants` and fetch
   the story **and all its subtasks** live via the Asana connector — every run,
   never from memory or this repo. No live template is read here: the run-sheet
   layout is this skill's own structure (`references/run-sheet-format.md`), not an
   Asana-authored template. Constants are resolved by GID, never hardcoded.
2. **The story's `Development` subtask should be done** (the story's own Gherkin:
   *GIVEN a story URL whose Development subtask is done*). Check it and **say so**
   in the output. If it is not done, **flag it** — "Development not marked done;
   generating anyway" — rather than refuse; the story text gates on it, so QA
   decides whether to proceed.

These two preconditions carry different postures: a not-done `Development` subtask
is a **soft flag** QA can override, whereas a story with no `[AC]`s is a **hard
refuse** (Run flow step 1) — no `[AC]`s means no definition of done to test, so
there is nothing to generate.

## Run flow

1. **Fetch the story and its subtasks** (Preconditions step 1). Handle the failure
   and empty states before generating — see `references/routing-and-edges.md`:
   - **Story unreachable** (bad link / invalid GID, or no access) → stop and name
     the **exact access fix**; distinguish a bad link from an access denial, the
     fixes differ.
   - **No `[AC]`s** → **refuse** and route to `raftkit-pm/story-readiness` — an
     unready story cannot be tested.
2. **Parse the story.** Match `[AC]` subtasks by the leading `[AC] ` token; read
   the Gherkin-scenarios section and the WEESLD edge-cases section; read the
   permission boundary from the header (`Who is allowed / not allowed`). Parse
   robustly — stories are hand-authored (match sections by meaning, not
   punctuation; expect the template's intentional numbering gap).
3. **Reuse the project suite where one exists** (`references/suite-slice.md`).
   Where a project test suite Sheet exists, pull the **matching cases by case ID**
   — no duplication — and add story-specific steps for the rest. If the suite
   Sheet is unreachable, **generate standalone and say the slice link is missing**;
   never block generation on the suite.
4. **Generate the numbered run sheet** to the fixed layout
   (`references/run-sheet-format.md`): one numbered step per line with start state,
   action, test data, and the verbatim expected result. Deterministic steps only —
   start state, action, expected — **no "verify it works" steps**. Every `[AC]`
   maps to **at least one** runnable step. Make **every WEESLD state and every
   permission boundary an explicit step group**. Steps take the default status
   (`references/run-sheet-format.md`).
5. **Flag the coverage gaps.** List every `[AC]` with no runnable step and every
   WEESLD state the story's `[AC]`s leave uncovered, naming them to **QA and the
   PM**. The sheet covers what exists and names what doesn't.
6. **Report** using the exact success line from `references/run-sheet-format.md`.

Generation stays **fast** — a single pass over the fetched story; it runs per
story, every story, so there is no heavy multi-pass analysis.

## When a step fails during the run

A failing step routes to **`file-bug`** with the failing step attached — this skill
only **routes**; it never files the bug itself (that is `file-bug`'s job, which
creates the bug under the story's `Bugs` subtask). See
`references/routing-and-edges.md`.

## Guardrails

- **Read-only on Asana.** This skill reads the story and (optionally) the suite
  Sheet; it writes no Asana task and files no bug. Its output is the run sheet in
  chat and/or appended to a **separate run-sheet tab or Sheet — never the suite
  Sheet's case rows** (those are `test-suite`'s surface, keyed by case ID). That
  append is a write: gate it draft → approve, per `raftkit-core/write-protocol`.
- **No new requirements.** The sheet restructures the story into steps; it adds no
  behaviour, no acceptance criterion, and no expected result the story does not
  state.
- **Asana free tier** and **escalate-to-founders** rules per
  `raftkit-core/house-rules` apply to anything this skill touches.

## Out of scope

- **Automated execution** — post-pilot; the sheet is a manual guide, no runner and
  no auto pass/fail.
- **Bug filing** — `file-bug` owns it; the sheet only routes a failing step to it.
- **Generating or syncing the project suite** — that is `test-suite`; this skill
  only *reuses* an existing suite's cases by case ID.
- **Marking pass/fail** — execution marks belong to QA; the skill produces the
  sheet with every step at the default status.

## Reference files

- `references/run-sheet-format.md` — the fixed step layout, the determinism rules,
  the WEESLD + permission step groups, the default step status (aligned with
  `test-suite`), the exact-strings rule, and the verbatim success line.
- `references/suite-slice.md` — reusing an existing suite's cases by case ID (the
  case-ID scheme is owned by `test-suite/references/sheet-format.md`), the
  no-duplication rule, and the suite-unreachable fallback.
- `references/routing-and-edges.md` — the empty state (route to `story-readiness`),
  the story-unreachable access fixes, and routing a failing step to `file-bug`.
