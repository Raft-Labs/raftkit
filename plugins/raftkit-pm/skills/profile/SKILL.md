---
name: profile
description: Build or update a project's Project Profile in Asana from the sources the PM names — "onboard this project", "build the project profile", "set up the source of truth for project X", or a re-run with a new source. Every fact tagged ✅/⚠️/❓ and cited; conflicts shown, never resolved; one stop before the write.
user-invocable: true
---

# profile

Turn what the PM has (PRD, SOW, master doc, emails, meeting notes) into one Project Profile: the tagged, cited source of truth every other skill reads. `raftkit-core:rules` apply.

## Inputs, in one ask

At least one **named source** (Drive, Gmail, Fathom, Asana, an upload, a pasted link, a synced file) and the **Asana project** the profile belongs to. Never infer the project from a source and never read a source the PM did not name. Missing either → stop and ask for exactly that; create nothing.

Resolve the project name against Asana: one match → carry on and show it as `<name> (gid)`; several → ask which, listing them; none → say so.

## Run

1. **Read at once**: every named source, and the existing `Project Profile - <project name>` task if there is one (its presence decides first build vs delta). An unreadable source is named with the access that is missing and listed as skipped; the rest are read.
2. **Draft facts** per `references/format.md`: one sentence each, one tag, one citation, an as-of date; anything not clearly confirmed is ⚠️ Partial; a gap is ❓ Missing, never a guess; two sources that disagree become a conflict with both citations for the PM to settle.
3. **Re-run** → a delta, never a rewrite: changed / new / now-confirmed facts, touching only the subtasks whose sections changed. Untouched facts stay exactly as they were.
4. **Stop once.** Show the profile or the delta in the shape it will be written (lists, never tables), the project as `<name> (gid)`, the subtasks that will be created or overwritten, and for a delta the one comment that records it. A corrected project re-targets the same draft; the sources are not re-read.

```output
Profile draft for Riverside Bookings (1216…). 4 subtasks, 38 facts: ✅ 21 / ⚠️ 12 / ❓ 5. 2 conflicts.
**STOP** — approve to write, edit to change, or decline.
```

5. **On go**, write the parent task, its subtasks, then the delta comment; read back once. A timed-out write is looked up by name before any retry so a second profile task is never created. Report:

```output
38 facts — ✅ 21 / ⚠️ 12 / ❓ 5. Top gaps: payment provider, refund window.
Profile lives at: <link>
```

- **Announce it** — `Using raftkit-pm:profile` in the first reply, once (`raftkit-core/cowork-telemetry`).
