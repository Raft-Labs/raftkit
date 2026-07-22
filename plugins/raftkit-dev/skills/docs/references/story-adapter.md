# Story adapter — docs → Asana user stories, live template

Generates one Asana user story per feature from the generated docs, using the
organization's **live** User Story Template fetched at run time. No template
body is ever cached in this plugin; the template is read live by GID (via the
core workflow-constants) and its section structure drives the render. All
writes go through core `asana-formatting` and the `write-protocol` gate —
draft → approve → push. This skill never calls Asana directly outside that gate.

## What it produces

One story per feature, mapped entirely from the already-generated docs — never
invented. Every section is filled from a doc; a section with no source is left
as `TBD` and flagged for the human. The story mirrors the live template exactly,
including its section numbering (the template's own 9 → 11 numbering skip is
preserved verbatim — the numbering comes from the fetched template, never from
memory):

- Story header, Gherkin scenarios, business rules, data/entities, the WEESLD
  edge-case rows, UI/copy, side effects, out-of-scope, technical context.
- `[AC]` subtasks, one per independently verifiable criterion — 5 to 12 per
  story; beyond 12, advise splitting the feature.

## The link registry

`docs/project/asana.json` (or the repo-approved equivalent) is the registry. It
stores **only GIDs and sync versions** — workspace/project/section GIDs, a
spec-URL prefix, and a `storyRegistry` mapping each feature slug to
`{ taskGid, lastSyncedVersion }`. No template text, no story body — those are
fetched or generated fresh.

- On change tracking, a materially changed feature doc marks its story stale;
  the refreshed draft **updates the existing task** (matched by `taskGid`),
  never duplicates it. New ACs are added; obsolete ACs are commented; **completed
  AC subtasks are never deleted**. `lastSyncedVersion` bumps after the sync.
- The **parent story task is never auto-completed** — the human closes it.

## Offline

When the connector is unavailable, an offline artifact may be produced **only**
from a template fetched in the current run, with provenance recorded (the source
GID and the fetch time). If no template could be fetched this run, no artifact
is produced and the capability is reported blocked — a stale or cached template
is never used.

## AC-tick offers

When a validation category passes, the matching `[AC]` subtasks are **offered**
for completion — drafted, shown, and pushed only after explicit approval through
the write-protocol gate. Ticking is never automatic, and the parent story is
never completed on the skill's own initiative.
