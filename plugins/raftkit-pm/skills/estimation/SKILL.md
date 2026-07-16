---
name: estimation
description: This skill should be used when a RaftLabs PM wants a task-level effort estimate for a ready story before fixed-scope quoting — e.g. "estimate this story", "break this story into dev tasks with hours", "how long will this task take to build", "give me the estimate for this Asana story". It gates on story-readiness (estimates only ready stories), decomposes the story into dev tasks mapped 1:1 to its ACs/scenarios, gives every task an hour RANGE with named assumptions, widens ranges for ⚠️ Partial profile areas, and opens every output with the mandatory founder-review watermark. Read-only; it never prices, quotes, promises timelines, or plans capacity — those are founder decisions.
user-invocable: true
---

# estimation

Turn a **ready** story into a task-level effort breakdown: dev tasks mapped 1:1 to
the story's `[AC]`s and scenarios, each an hour **range** with its assumptions,
opened by the mandatory founder-review watermark. Fixed-scope is the business model
and an estimate commits the business, so the house rule applies — no timeline or
budget commitment without founder review (PRD §3, §5.2, §10.6). This skill produces
the breakdown; it never turns one into a price, a quote, or a promise.

## The two rules that govern everything

- **Ready-only, or refuse.** Estimate a story only after it passes the
  [story-readiness](../story-readiness/SKILL.md) gate. A not-ready story gets a
  refusal plus the readiness gap list — never a hedged estimate. Estimating
  unspecified scope produces fiction, not an estimate.
- **Never a commitment.** Every output opens with the exact watermark
  **`Requires founder review — not a client commitment.`** — first line, every run,
  no flag or option disables it. Estimates are ranges, never single points, and this
  skill never prices, quotes, promises a delivery date, or plans capacity: those
  escalate to founders (`raftkit-core/house-rules`).

## Inputs

1. **The story** — a task link or GID. If none is given, ask for one.
2. **The Project Profile (optional, read-only)** — consulted only for `⚠️ Partial`
   markers that widen ranges. Its home is an open decision, so there is no default
   path: the PM points at the approved profile, or there is none. When no profile is
   supplied, say so and estimate without profile-driven widening — never invent a
   profile or a `⚠️ Partial` marker.

## Run flow

1. **Gate on readiness.** Run [story-readiness](../story-readiness/SKILL.md) on the
   story and consume its verdict — do not rebuild the checklist here. story-readiness
   returns a binary **PASS / NOT READY**; branch on the NOT READY *reason*, checking
   the empty case first:
   - **Empty description** — NOT READY because the description is empty → route the PM
     to the [user-story](../user-story/SKILL.md) skill to write the story first, then
     re-run estimation. Do not dump a gap list here.
   - **NOT READY (gaps, not empty)** → refuse: return story-readiness's gap list
     verbatim and state that estimating unspecified scope produces fiction, not an
     estimate. Emit no numbers.
   - **Bad link / no access** → surface the access problem exactly as story-readiness
     reports it, and name the fix.
   Every one of these outputs still opens with the watermark.

2. **Fetch the ready story.** On **PASS**, fetch the story and all its subtasks live
   via the Asana connector. Its `[AC]` subtasks and its Gherkin scenarios are the
   units to estimate. If the PM supplied a Project Profile, read it now (read-only).

3. **Decompose 1:1.** Build dev tasks mapping one-to-one to the story's `[AC]`s and
   scenarios, per `references/breakdown-method.md`. Every task carries an hour
   **range** (low–high) and at least one **named assumption**. No single-point
   numbers anywhere.

4. **Price uncertainty visibly.** For any task touching a story area the profile
   marks `⚠️ Partial`, widen that task's range and name the driving assumption on its
   line.

5. **Total and collect assumptions.** Sum the task ranges into a total range and
   gather every assumption into one list. One story per run; an epic is estimated
   sub-story by sub-story and summed with the combined assumptions.

6. **Emit.** Output opens with the watermark as its first line, then the breakdown,
   the total range, and the assumption list — the exact shape is in
   `references/breakdown-method.md`. Read-only: nothing is written to Asana.

## Guardrails

- **Watermark, always, undisableable.** The exact string
  `Requires founder review — not a client commitment.` is the first line of **every**
  output — happy path, refusal, empty, error. No flag, option, or phrasing suppresses
  it.
- **Ranges, never points.** Every number is a low–high range. Confidence is a tight
  range; uncertainty is a wide one; a bare single number is never emitted.
- **Every range carries an assumption.** A range with no stated assumption is
  incomplete.
- **1:1 to the story.** Tasks map to the story's `[AC]`s/scenarios so a scope change
  re-prices mechanically — never estimate work the story does not specify, never drop
  an `[AC]`.
- **Not ready = refusal, not a hedge.**
- **Founder territory stays out.** No pricing, margins, or quotes; no delivery-timeline
  promises; no capacity planning. The skill estimates effort only; these escalate to
  founders (`raftkit-core/house-rules`).
- **Read-only.** Never writes, edits, or creates anything in Asana; the breakdown
  lives in chat.
- **No cached template.** Estimation consumes the story's own structure and delegates
  the live-template read to story-readiness; it stores no template text
  (`raftkit-core/house-rules`).

## Reference file

- **`references/breakdown-method.md`** — how to decompose a ready story into dev tasks
  1:1 with its `[AC]`s/scenarios, the range-and-assumption rules (never a point), how
  `⚠️ Partial` widens a range and names its driver, epic handling, and the exact output
  shapes (success, refusal, empty).
