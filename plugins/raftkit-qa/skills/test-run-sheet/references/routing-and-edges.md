# Routing and edge states

Where the run sheet stops, refuses, or hands off. Each state has one correct route;
none of them fabricates a sheet from an inadequate story.

## Empty — a story with no `[AC]`s

A story with **no `[AC]` subtasks** cannot be tested: there is no definition of
done to derive steps from. Do **not** generate a sheet from a description alone.
**Refuse and route to `raftkit-pm/story-readiness`** — the Definition-of-Ready gate
— so the story is made ready first, then re-run. An unready story tests nothing;
generating against it would ship a run sheet that asserts nothing.

## Error — the story is unreachable

Distinguish the two cases; the fix differs and QA needs the right one:

- **Bad link / invalid GID** (the task does not exist or the identifier is
  malformed) → report exactly that the link is bad and name the fix ("check the
  task URL / GID").
- **No access** (the task exists but the connector is denied) → report exactly that
  it is an access problem and name the fix ("you don't have access to this task —
  request access or check the connector").

In both cases stop before generating; a sheet built from a story you could not read
is a guess.

## Coverage gaps — flag, never paper over

The run sheet covers what the story contains and **names what it does not**:

- **Unmapped `[AC]`** — an `[AC]` for which no runnable step could be derived is
  listed as a gap, naming the `[AC]`.
- **Uncovered WEESLD state** — a WEESLD state the story's `[AC]`s leave uncovered is
  listed as a gap, naming the state.

Gaps are named to **QA and the PM** — QA so they know the sheet is not exhaustive,
the PM so the story can be completed. A non-empty gap list flips the success line's
tail to `gaps: listed` (`run-sheet-format.md`); an empty one leaves it `gaps: none`.
Never silently omit a criterion to make the sheet look complete.

## Routing a failing step to `file-bug`

When a step fails during execution, the failure routes to **`file-bug`** with the
**failing step attached** (its number, action, and expected result travel with the
handoff, so the bug reproduces the exact step). This skill only **routes** — it
never creates the bug. `file-bug` owns filing: it reads the live Bugs Template and
files the bug as a subtask under the target story's `Bugs` subtask after QA
approves the draft. Filing the bug here would duplicate that skill and bypass its
draft-approve gate.
