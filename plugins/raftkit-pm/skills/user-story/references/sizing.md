# Sizing — one story, an hour range, nothing more

How user-story answers "if I hand this one story to a developer, is it a day or
a week?". It arises mid-project on a client change request, or post-v1 on a new
ask.

The boundary is the **kind of answer**, not the number of stories. One hour range
for the whole story is answered here. A task-level breakdown — hours per
acceptance criterion, the thing a fixed-scope quote is built from — belongs to
`estimation`, for a single story as much as for a list. An ask for an estimate,
a breakdown, or a quote is estimation's even when it names one story.

The conventions are estimation's own — a range, named assumptions, wider where
knowledge is thin, and the founder-review watermark. Any output carrying numbers
also carries estimation's approval chain (`raftkit-core/house-rules`). They travel
with the number so that leaving the estimation skill never leaves the guardrails
behind.

## When this path runs

Sizing runs on either of two triggers:

- The PM asks how long, right after this skill wrote the story.
- The PM names an existing story and asks for its size.

Read the story live before answering — its own `[AC]` subtasks and scenarios are
what is being sized. Never size a story from memory of an earlier run.

## Sizing does not run the readiness gate

`estimation` refuses a story that fails readiness. Sizing does not, and that is
deliberate: a PM asking a ten-second question should not be sent away to close
thirteen story gaps first. Size what the story actually says, and turn each
unresolved area into a **named assumption** on its own line. An unwritten error
state or a missing rule widens the range; it never blocks the answer.

## The number

- **A range in hours, never a single number.** Tight range for confidence, wide
  for uncertainty. A bare figure reads as a promise.
- **Never convert hours into days.** A day figure reads as a delivery date, and
  dates are founder territory. Hours only, even when the question was phrased in
  days or weeks.
- **Every range carries at least two named assumptions** — the condition under
  which the low holds, and what pushes it toward the high.

## Widen where knowledge is thin

Widen the range, and name the driver on its own assumption line, when any of
these is true:

- The Project Profile marks a story area **`⚠️ Partial`**, or is silent on it.
- No Project Profile was supplied, or the one supplied could not be read.
- The story leaves a rule, an error state, or a permission boundary unwritten.

Never manufacture a `⚠️ Partial` marker where no profile exists. Say that no
profile was supplied and widen on that basis.

**The range absorbs every named driver.** Never quote a base-case range and hang
the risks underneath it as add-ons. A reader forwards the headline number and
leaves the bullets behind, so a tight range with `+8 h` beneath it understates
the work by design. The high end already covers what happens if the named drivers
land, and one assumption line states the condition under which the low end holds.
Work that is genuinely excluded from the range is named as excluded, in words,
without an hour figure attached.

## Reuse an estimate the project already holds

Before sizing from scratch, check whether the project already estimated this
work. If it did, **cite the current figure rather than deriving a new one**, and
say in one line which source it came from. Where sources disagree, use the most
recently refined one and flag in one line that older figures are stale. One
line — reconciling a document set is not this answer's job.

## Hard cap on the output

The question is small and the answer stays small. The whole reply is the
watermark, the approval chain line, a one-line subject, the range, an
`Assumptions:` label with two to four bullets, and the closing founder line.
Nothing more. A bullet naming excluded work counts against those four. No
task-level table, no per-`[AC]` breakdown, no programme totals, no
document-hygiene advice. A long answer to a short question buries the number
that was asked for.

**Nothing precedes the watermark.** No preamble, no note on which sources were
read, no remark about the task's name or the route the question took. The
watermark is the first line of the reply itself, not the first line of a block
further down. A reader who copies the top of the message must get the warning,
and anything above it takes the warning's place.

**Nothing follows the closing founder line.** No trailing advice, no readiness
commentary, no "two things worth your attention". Whatever the sizing turned up
belongs in an assumption line or is left out. The closing line ends the reply.

Both rules hold on either trigger — asked directly against an existing story, or
asked right after this skill wrote one.

## Output shape

```output
Requires founder review — not a client commitment.
AI estimate → vetted by the developer who will build it → approved by Nirav or Ashit → only then shared with the client.

Sizing — calendar sync (one-way, Microsoft)

30–51 h

Assumptions:
- The low end holds only if the 13 open story questions land as written.
- Taken from the refined 3 August estimate. An older client-facing draft says 38 h and is unreconciled.
- Microsoft app registration settings are unconfirmed. That risk sits inside the range.
- Excluded: save-and-retry on a provider outage, which is still unconfirmed.

Pricing, dates and programme totals are founder calls.
```

## Out of scope

- **Bulk feature-list estimation** — stays in `estimation`.
- **Pricing, quoting, or any timeline commitment** — founders only
  (`raftkit-core/house-rules`).
- **Capacity planning and delivery dates** — never inferred from a range here.
