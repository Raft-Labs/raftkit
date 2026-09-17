# Project Profile format

## A fact

Statement (one sentence, no more than 25 words) + tag + citation (doc and section, email and date, meeting and timestamp, task GID, or "uploaded file, as-of <date>") + as-of date. A ✅ or ⚠️ fact without a citation is not allowed; a ❓ fact cites the gap.

| Tag | When |
|---|---|
| ✅ Confirmed | stated unambiguously in a source and cited |
| ⚠️ Partial | implied, incomplete or single-source-thin; the default |
| ❓ Missing | explicitly absent; a gap, never a guess |

A conflict is not a tag: the fact, then each competing value with its own citation, left for the PM.

## Sections

Start from glossary · roles and permissions · business rules and limits · source index (every source with link and as-of date). Add sections the sources support; never invent one to fill. Split a section past about 15 facts, or whenever it needs headings inside it.

## Where it lives

One task `Project Profile - <project name>` in the project it describes. The parent description carries only the project, the as-of date, the source index headline and the tag legend once. One subtask per section, named with a plain gloss after a dash, opening with one line saying what it holds and how many facts:

```output
Roles and permissions — who is allowed to do what
18 facts on who approves what and who owns which area.
```

Facts render as lists (a bold label, then citation and date), never tables. Only two heading levels exist.

## Delta comment

One comment on the parent task per delta run, recording what changed, not the new content: source added, subtasks rewritten, then only the groups with entries — Changed (old tag → new tag, why, citation) · New · Conflicts added · Now-confirmed. Group labels as bold lines with lists under them. Asana keeps no history of an overwritten description; this comment is the only trace.
