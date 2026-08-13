# Breakdown method — story to task-level effort, ranges and assumptions

How estimation turns a **ready** story into the effort breakdown. The method exists
to make one thing true: a scope change re-prices mechanically, because every number
traces to a specific `[AC]` or scenario in the story.

## Decompose 1:1 with the story

The units are the story's own `[AC]` subtasks and its Gherkin scenarios — not a
freshly invented task list.

- Enumerate the `[AC]` subtasks by **leading-token** match (`[AC] `) and the Gherkin
  scenarios in the description. Each becomes one line in the breakdown.
- Cross-cutting work (setup, wiring, plumbing) **attaches to the `[AC]` that
  requires it** — it does not become a task the story never asked for.
- **Never invent a task beyond the story's scope, and never leave an `[AC]`
  unestimated.** A missing line or an extra line breaks the 1:1 traceability that
  lets scope changes re-price without a re-think.

## Ranges, never points

Every estimate is a low–high range in hours. A single number is forbidden **even
when you are confident** — express confidence as a *tight* range and uncertainty as
a *wide* one. A point estimate reads as a promise; fixed-scope quoting needs the
spread visible so founders can see the risk they are pricing.

## Every range carries a named assumption

Each range names **at least one assumption** — the condition under which the low
holds and what would push it toward the high (e.g. "assumes the auth provider's SDK
is already wired", "assumes no new data migration"). A naked range is incomplete:
without its assumption, no one can tell whether the number is safe.

## ⚠️ Partial areas widen the range

When a task touches a story area the Project Profile marks **`⚠️ Partial`** —
project knowledge that is known to be incomplete — **widen that task's range** and
**name the driving assumption** (the specific unknown forcing the spread) on that
task's line. Match a task to a profile area by the story component it exercises (e.g.
auth, payments, a named integration); when the profile marks that area `⚠️ Partial`,
widen. If the mapping is unclear, name the uncertainty itself as the driving
assumption rather than assuming coverage. Partial knowledge is priced as risk, out in
the open, not smoothed into a falsely tight number. If no profile was supplied, there
are no `⚠️ Partial` markers to act on — say so; do not manufacture one.

## Epics — one story per run

Estimate one story per run. An epic is estimated **sub-story by sub-story**: break
each sub-story down by the rules above, then sum into a combined total carrying the
**union** of every sub-story's assumptions. Say explicitly that the total is an epic
sum across N sub-stories.

## Output shapes

The watermark is always the first line. Use literal `—`, `→` and `⚠️`; keep it plain
so it reads cleanly in chat. The approval chain follows the watermark on any shape
that carries numbers, so those numbers carry their route to the client. Shapes that
carry no numbers — refusal, empty, error — have nothing to route: they omit the chain
line and keep their own explanatory text under the watermark.

### Success

```output
Requires founder review — not a client commitment.
AI estimate → vetted by <implementing developer> → approved by Nirav or Ashit → only then shared with the client.

Estimate — <story title>

- <[AC] / scenario> — <low>–<high> h — assumes <assumption>
- <[AC] / scenario> — <low>–<high> h — assumes <assumption>  ⚠️ widened: <driving assumption>
- ...

Total: <sum-low>–<sum-high> h
Assumptions:
- <assumption>
- <assumption>
```

### Refusal — story not ready

```output
Requires founder review — not a client commitment.

Cannot estimate — the story is not ready.
<story-readiness gap list, verbatim>
Estimating unspecified scope produces fiction, not an estimate. Fix the gaps, then re-run.
```

### Empty — no story to estimate

```output
Requires founder review — not a client commitment.

No story to estimate — the task description is empty. Write the story first with the
user-story skill, then re-run estimation.
```
