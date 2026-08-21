---
name: estimation
description: This skill should be used when a RaftLabs PM needs a whole feature list estimated at proposal time — a new project has landed, a fixed-scope proposal is due, and every feature needs FE/BE/QA hours in one place. Trigger on "estimate this feature list", "we need hours for the proposal", "break this scope into FE/BE/QA hours", "estimate the features in this sheet", "estimate the backlog for project X". It takes the feature list in whatever form the PM has it — pasted, a scope document, or a Google Sheet listing the features — gives every feature an hour RANGE for FE, BE and QA with named assumptions, widens ranges where project knowledge is thin, and writes the result to one Google Sheet after approval. Every output opens with the founder-review watermark and the estimation approval chain. A request about one story is redirected to raftkit-pm:user-story, which sizes a story. Hours only — it never prices, quotes, promises a date, or plans capacity.
user-invocable: true
---

# estimation

Turn a **whole feature list** into hours: every feature gets an FE, a BE and a QA
hour **range** with its assumptions, totalled, and written to one Google Sheet the
PM can export for a proposal. This is the job a PM has when a new project lands and
a fixed-scope proposal is due — the list is long, the detail is thin, and a number
is needed today.

Fixed-scope is the business model and an estimate commits the business, so the house
rule applies — no timeline or budget commitment without founder review (PRD §3, §5.2,
§10.6). This skill produces the hours; it never turns them into a price, a quote, or
a promise.

## One story is not this skill's job

**One story is user-story's job.** A whole feature list is estimated here; a single
story is sized by [user-story](../user-story/SKILL.md), which answers with one hour
range under the same watermark and the same approval chain. When the ask names one
story — however it is phrased, and whether or not it says "estimate" — hand it over
and stop, in the exact words of the `Redirect — the ask names one story` shape in
`references/sheet-output.md`. That file holds the wording; it is not restated here.
This is a redirect, not a refusal: the PM gets their answer, from the skill built
for it.

The boundary is the **size of the ask, not the word used**. Breaking one story into
per-criterion hours is not offered by either skill, and that is deliberate — it is
the mechanism that turned a small UI change into 85 hours.

## The two rules that govern everything

- **A list, not a story.** The unit is a feature. There is no readiness gate to pass
  and no story required — at proposal time there are usually no stories written yet,
  and that must never stop an estimate. Where a feature does map to a written story,
  its gaps widen that feature's range and get named; they never block the run.
- **Never a commitment.** Every output opens with the exact watermark
  **`Requires founder review — not a client commitment.`** — first line, every run,
  no flag or option disables it. Any output carrying numbers also carries the
  **estimation approval chain** (`raftkit-core/house-rules`): the named implementing
  developer vets the number, Nirav or Ashit approves it, and only then may a client
  see it. Estimates are ranges, never single points. This skill never prices, quotes,
  promises a delivery date, or plans capacity: those escalate to founders
  (`raftkit-core/house-rules`).

## Inputs

1. **The feature list** — in whichever form the PM already has it: pasted into chat,
   a scope or proposal document they point at, or **a Google Sheet that lists the
   features**, which is the common case when a proposal is already being drafted. If
   none is given, ask for one. Estimate the features the list actually names; never
   invent a feature it does not.

   A source Sheet is **read-only** — the estimate never writes back into it.

   **Find the feature column before asking for it.** Read the header row and look for
   the column that holds the features — headed `feature`, or an obvious variant such
   as `features`, `feature name`, `scope item`, `requirement`, or `epic`. One clear
   match is used, and the run says which column it read so the PM can correct it.
   Ask only when the Sheet is genuinely ambiguous: no header row, no column that
   reads as the feature column, or two equally plausible ones. The PM naming a
   column always wins over what the header suggests.

   Rows that are blank, struck through, or marked out of scope in a status column are
   skipped, and say how many were skipped so a dropped row is never silent.
2. **The implementing developer or team lead** — who vets the number. Required for
   any output that carries numbers: it fills the vetting link of the approval chain.
   There is no lookup source and no default — the PM names them. If none is given,
   stop and ask before emitting hours; never guess a name, and never emit numbers
   with that slot unfilled.
3. **Where the estimate Sheet lives** — the destination is a parameter the PM
   supplies, never a hardcoded path or file ID. One estimate, one Sheet, always a
   Sheet of its own: the estimate is never written into the source list, even when
   the source was itself a Sheet.
4. **The Project Profile (optional, read-only)** — consulted for `⚠️ Partial` markers
   that widen ranges. Its home is an open decision, so there is no default path: the
   PM points at the approved profile, or there is none. With no profile, say so and
   widen on that basis — never invent a profile or a `⚠️ Partial` marker.

## Run flow

1. **Check the size of the ask.** One story → the redirect above, and stop. A list of
   features → continue. An empty or missing list → ask for it; emit no numbers.

2. **Read the sources.** Take the feature list as given. When it is a Sheet or a
   document, read it now and echo back the features found and the count, so the PM
   can see the list was read as they meant it. If the PM supplied a Project Profile,
   read it too (read-only). If a feature names a written Asana story, fetch it live
   and let its gaps feed the assumptions — never as a reason to refuse. If a source
   cannot be reached, name the exact access fix and stop, in the
   `Source unreachable — nothing estimated yet` shape in
   `references/sheet-output.md`.

3. **Estimate each feature.** Give every feature an FE, a BE and a QA range with at
   least one named assumption, per `references/breakdown-method.md`. A feature with
   no work on a discipline gets a zero on that discipline, stated, not a blank.

4. **Price uncertainty visibly.** Widen where project knowledge is thin — a
   `⚠️ Partial` profile area, no profile at all, or a feature described in one line —
   and name the driver that widened it. The range absorbs its drivers; hours are
   never hung underneath it as add-ons.

5. **Total.** Sum to a FE, BE, QA and overall range, and gather every assumption into
   one list.

6. **Draft, then write after approval.** Show the estimate in chat first. On the PM's
   approval, write one Google Sheet in the fixed layout and report the link
   (`raftkit-core/write-protocol` — silence is not approval). The layout, the write
   rules, the connector-absent state, and the exact output shapes are in
   `references/sheet-output.md`.

## Guardrails

- **Watermark, always, undisableable.** The exact string
  `Requires founder review — not a client commitment.` opens **every** output, chat
  and Sheet alike — estimate, redirect, empty, error, and row 1 of the Sheet itself.
  No flag, option, or phrasing suppresses it. The approval chain line follows the
  watermark on any output carrying numbers, and is equally undisableable there: line
  2 in chat, row 2 in the Sheet. Outputs with no numbers omit the chain line and keep
  their own explanatory text under the watermark.
- **Ranges, never points.** Every number is a low–high range. Confidence is a tight
  range; uncertainty is a wide one; a bare single number is never emitted.
- **Every range carries an assumption.** A range with no stated assumption is
  incomplete.
- **Hours only, never days.** A day figure reads as a delivery date, and dates are
  founder territory — answer in hours even when the question was asked in weeks.
- **Estimate the list, nothing else.** Never add a feature the list does not name,
  and never silently drop one. A scope change re-prices by editing the list.
- **Founder territory stays out.** No pricing, margins, or quotes; no delivery-date
  promises; no capacity planning. This skill estimates effort only; the rest
  escalates to founders (`raftkit-core/house-rules`).
- **The only write is the Sheet**, and only after the PM approves the draft
  (`raftkit-core/write-protocol`). Nothing is written to Asana.
- **No cached template.** Any Asana story consulted is read live
  (`raftkit-core/workflow-constants`); no template text is stored here.
- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.

## Reference files

- **`references/breakdown-method.md`** — how a feature list becomes FE/BE/QA hour
  ranges: the feature as the unit, the range-and-assumption rules, what widens a
  range and how the range absorbs its drivers, and how the list totals.
- **`references/sheet-output.md`** — the Sheet contract: the fixed layout, with the
  watermark and approval-chain rows above the header row and the six columns under
  it, who owns structure and who owns content, the draft-then-write gate, the
  connector-absent state, and the exact chat shapes — an estimate, the single-story
  redirect, an empty list, an unreachable source, and an unreachable Sheet.
