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
  date, meeting + timestamp, task GID). A ✅ or ⚠️ fact without a citation is not
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

## Where the profile lives (parameterized — do not hardcode)

The canonical home of the profile is an **open decision** on the raftkit board.
Until it lands, treat the home as a parameter the PM supplies:
the PM points onboarding at where the profile lives (and where downstream skills
read it from), and the skill records that location. Never hardcode a path or a
single connector.

**Recommended default**, if the PM has no preference: a Google Drive doc for the
profile plus a pinned Asana resource task that links it, so every skill can reach
it by link. Offer this default, note it is provisional pending the decision, and
record wherever the profile actually lands so re-runs find the same home.

## Reporting back (success summary)

On a completed run, summarize the profile and give the count in this shape:

```
X facts — ✅ a / ⚠️ b / ❓ c. Top gaps: …
```

where the top gaps are the most delivery-critical ❓ Missing (and thin ⚠️ Partial)
facts. Then offer to run `story-skill-generator` for the project.
