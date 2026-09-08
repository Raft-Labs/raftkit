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

**Keep a fact to one sentence.** The house plain-language rules apply to a profile
like any other thing a human reads (`raftkit-core/house-rules`): no sentence over
25 words. A fact that needs three clauses is usually three facts — split it, and
let each carry its own tag, because a 60-word bullet hides which part is confirmed
and which is not. Detail that only matters to someone chasing the source belongs
in the citation, not the statement.

Group the facts into the sections a delivery team actually reads — a **glossary**,
**roles and permissions**, **business rules and limits**, and a **source index**
(every source with its link and as-of date). The glossary, roles, and source index
map directly onto elements `story-skill-generator` later bakes; its fourth baked
element — the conflict hierarchy — is the PM's to supply at bake time, since
onboarding surfaces conflicts and never resolves them.
Keep the structure to what the sources support — do not invent sections to fill.

**One subject per section, and split before it gets long.** These four are a
starting point, not a ceiling: a project whose sources carry more gets more
sections. Two rules decide when to split:

- **Past about 15 facts**, a section becomes hard to read — split it by subject.
- **If a section needs headings inside it**, those headings are the sections. A
  "business rules" section holding guardrails, protocols, enforcement gates and
  success metrics is four sections wearing one name.

Splitting costs nothing — a reader opens the one subtask they need instead of
scrolling past four they don't.

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

The profile lives **in Asana**, in the project it describes: one task named
`Project Profile - <project name>`, carrying **one subtask per section** — decided
on the raftkit board (task `1216550765662503`). The convention is fixed in
`raftkit-core/workflow-constants`, so no skill asks a human where a profile lives
and no run has to remember where the last one landed. There is no per-project
override: a home that varies is a home nobody can be sure of.

The parent task's description carries only what identifies the profile — the
project, the as-of date, the source index's headline, and the tag legend **once**.
Every section's facts live in its own subtask, which is what keeps any single
description readable. Never repeat the legend in each subtask; five copies of the
same three lines is the first thing a reader has to skip past.

**Name a subtask so someone who has never seen a profile knows what is in it.**
The section name alone does not do that — `Roles and permissions` and `Source
index` mean something once you know the format and nothing before then. Give each
one a short plain-English gloss after a dash:

```output
Glossary — what the project's terms mean

Roles and permissions — who is allowed to do what

Business rules and limits — the rules the product must follow

Source index — every source, with its link and as-of date
```

**Open each subtask with one line** saying what it holds and how many facts, so a
reader can decide whether to open it: *"18 facts on who approves what and who owns
which area."* That line replaces the legend, and it is the only preamble a subtask
gets.

Onboarding **takes the Asana project as an input** and stops if it is not given
one; it does not create projects. Sources are unaffected by any of this: a PRD,
SOW, or transcript still arrives on whatever path the session provides — Drive
connector, upload, synced folder, pasted link — per `raftkit-core/house-rules`.
Drive remains a place sources are read from, never where the profile is written.

**Render facts as lists, never as a table.** Asana renders no table in a task
description (`raftkit-core/asana-formatting`), and a fact's four parts read
naturally as a `<strong>` label followed by its citation and date. Only two
heading levels exist, so keep each subtask's structure shallow. A conflict is a
nested list too — the fact, then each competing value with its own citation
underneath — never two columns.

**Draft it in the shape it will be written.** The draft shown for approval is what
lands in Asana, so it carries no table either, even in chat where a table would
read more neatly. Approving a shape Asana cannot render means approving something
that will not exist.

## Recording a delta

Asana keeps no history of a description edit — an overwritten subtask leaves no
trace of what it said before, and its story feed stays silent. So a delta that is
not recorded is a change nobody can audit afterwards.

Every delta run therefore posts **one comment on the parent task** once the writes
land. One comment per run, never one per subtask: a delta is a single event and
reads as one. It records **what changed, not the new content** — the facts
themselves already live in the subtasks, so repeating them there would only grow
with the profile rather than with the change:

```output
Delta — <date>
Source added: <source, with its link or GID>
Subtasks rewritten: <names>

Changed
- <fact> <old tag> → <new tag> — <why, with the citation>

New
- <fact> (<citation>)

Conflicts added
- <fact> — <value A source> vs <value B source>

Now-confirmed
- <fact> lifted to ✅ by <citation>
```

List only the groups that have entries. Comments are the most restricted Asana
surface — no headings and no `<hr/>` — so render the group labels as `<strong>`
lines with lists under them (`raftkit-core/asana-formatting`).

This is an audit trail, not a backup: it says a fact moved and why, not what it
said before. Restoring an earlier value means going back to its source.

## Reporting back (success summary)

On a completed run, summarize the profile and give the count in this shape:

```output
X facts — ✅ a / ⚠️ b / ❓ c. Top gaps: …
Profile lives at: <link to the Project Profile task>
```

where the top gaps are the most delivery-critical ❓ Missing (and thin ⚠️ Partial)
facts. The `Profile lives at:` line is how the PM leaves with the address rather
than having to find it again; never omit it. Then offer to run
`story-skill-generator` for the project.
