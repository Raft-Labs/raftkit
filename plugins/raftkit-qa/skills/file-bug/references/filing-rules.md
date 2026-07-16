# Filing rules — title, axes, checklist, placement

## Title format

The story requires the title be enforced in the shape:

```
[Platform][Severity] short what + where
```

Enforce it on every draft — a title missing either bracket, or missing the
where, fails the pre-submit checklist below. This is the single canonical
statement of the pattern in this skill; the authoritative wording of the labels
inside the brackets is whatever the live template carries this run.

## Severity vs. priority — different axes, asked separately

These measure different things and are asked as two distinct questions, each on
the scale the live template defines:

- **Severity** — how bad the impact is (the template's severity scale, blocker
  through cosmetic).
- **Priority** — how urgently the business wants it fixed (the template's
  priority scale).

They can legitimately diverge — a homepage hero copy typo can be the lowest
severity yet the highest priority. An odd-but-legal combination like that is
**confirmed with QA, not blocked**: surface it, ask QA to confirm it is
intentional, then proceed.

## Reproducibility

Default to "Always" only when the Jam shows it; otherwise ask QA (see
`jam-evidence.md`).

## One bug per ticket

A recording that captures unrelated issues becomes **separate drafts and separate
tickets** — one bug per ticket, enforced, never merged. Batch filing is a
sequence of individual drafts, each going through its own approval.

## Pre-submit checklist (every item required before a push is offered)

These are the story's required minimum; the live template is authority for the
full list and may add to it.

- Type + Severity + Priority all set
- Environment filled — platform, environment, exact URL/screen, build/version,
  device/OS, and (web) browser + version
- Role + test account(s) provided
- Steps reproduce deterministically from a clean start
- Both Expected Result and Actual Result stated
- At least one piece of evidence attached
- Acceptance criteria ("Done when") defined

Any unchecked item **blocks the push** — return to QA to fill it before offering
to file.

## Asana placement

- Create the bug as a **subtask under the target story's `Bugs` subtask** — this
  is what makes traceability automatic.
- Apply the **project's priority tag** — the tag that represents the Priority
  value chosen above, in that project's own tag naming, resolved at run time from
  the target story's project (or ask QA). Never use a hardcoded project-specific
  tag name. If the project has no tag for the chosen priority, **ask QA — do not
  create one silently**.
- **Asana free tier** (`raftkit-core/house-rules`): tags only; no dependencies,
  custom fields, milestones, start dates, or approval tasks. Express any
  relationship (e.g. to the failing run-sheet step) as a task link in the body.
