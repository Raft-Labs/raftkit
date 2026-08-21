# Project Profile format

The Project Profile is the single tagged source of truth for one project. Every
downstream RaftKit skill reads it; nothing in a plugin duplicates what belongs
here (`raftkit-core/house-rules`). This file defines its shape, its confidence
tags, where it lives, and how a run reports back.

## A fact = statement + tag + citation + date

Every entry in the profile is one **fact** carrying exactly four things:

- **Statement** — the fact itself, in plain language.
- **Tag** — exactly one of ✅ Confirmed / ⚠️ Partial / ❓ Missing (below).
- **Citation** — the source it came from and where in it (doc + section, email +
  date, meeting + timestamp, task GID, or uploaded file + as-of date — an upload
  has no live URL). A ✅ or ⚠️ fact without a citation is not
  allowed; a ❓ fact cites the gap, not a value.
- **Date** — when the fact was last confirmed against a source (as-of date), so a
  re-run can tell fresh facts from stale ones.

Group the facts into the sections a delivery team actually reads — a **glossary**,
**roles and permissions**, **business rules and limits**, and a **source index**
(every source with its link and as-of date). The glossary, roles, and source index
map directly onto elements `story-skill-generator` later bakes; its fourth baked
element — the conflict hierarchy — is the PM's to supply at bake time, since
onboarding surfaces conflicts and never resolves them.
Keep the structure to what the sources support — do not invent sections to fill.

## The confidence tags

| Tag | When it applies |
|---|---|
| ✅ Confirmed | Stated unambiguously in a source and cited to it. The only tag that asserts certainty. |
| ⚠️ Partial | Implied, incomplete, single-source-thin, or otherwise not clearly confirmed. **The default.** |
| ❓ Missing | Explicitly absent — a known gap the profile records so it can be filled later. Never a guess. |

**Default rule:** anything not clearly confirmed is **⚠️ Partial, never ✅**. An
untagged fact is treated as ⚠️ Partial. Confidence is earned from a source; it is
never assumed to lift a fact to ✅.

**Conflicts** are not a tag. When sources disagree on the same fact, the profile
records the conflict with both citations and leaves it for the PM to resolve — see
`ingestion-and-deltas.md`. It is never silently collapsed to one value.

## Where the profile lives (decided)

The canonical home of the profile is **a Google Drive doc plus a pinned Asana
resource task on the project's board that links it** — decided on the raftkit
board (task `1216550765662503`). The resource task is the stable address every
skill and teammate reaches the profile through; the Drive doc is the content.
The Drive doc may be created and updated via the Drive connector **or** as a
file in the PM's synced Drive folder — same doc, either path, both through the
write-protocol gate.

State this home at the point of asking, as the default. A project that already
keeps its profile elsewhere names that home instead and the skill follows it —
sources and destinations stay access-path-agnostic (`raftkit-core/house-rules`).
Either way, record where the profile actually lives so re-runs and downstream
skills find the same home. Never hardcode a path or a single connector.

## Reporting back (success summary)

On a completed run, summarize the profile and give the count in this shape:

```output
X facts — ✅ a / ⚠️ b / ❓ c. Top gaps: …
Profile lives at: <the pinned resource task's link, or the home the PM named>
```

where the top gaps are the most delivery-critical ❓ Missing (and thin ⚠️ Partial)
facts. The `Profile lives at:` line is how the PM points every later skill — and
tomorrow's session — at the profile; never omit it. Then offer to run
`story-skill-generator` for the project.
