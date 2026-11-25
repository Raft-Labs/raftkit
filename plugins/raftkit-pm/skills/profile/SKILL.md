---
name: profile
description: Build or update a project's Project Profile in Asana from named sources or one client call — "onboard this project", "build the project profile", "turn this call into decisions and tasks", "what did we decide". Every fact tagged ✅/⚠️/❓ and cited; a call adds decisions, SCOPE CHANGE flags and a task batch; one stop before the write.
user-invocable: true
---

# profile

Turn what the PM has into one Project Profile: the tagged, cited source of truth every other skill reads. Load `raftkit-core:rules` first unless it is already in this conversation.

**Mode**: decisions or tasks from one call, with a Profile in place → **from a call**; anything else, a call included → **sources**.

## Inputs, in one ask

At least one **named source** (Drive, Gmail, Fathom, Asana, an upload, a pasted link) and the **Asana project** the profile belongs to. Never infer the project from a source and never read a source the PM did not name. Missing either → ask for exactly that; create nothing.

Resolve the project against Asana: one match → show `<name> (gid)`; several → ask which; none → say so.

## Sources

1. **Read at once**: every named source, and the existing `Project Profile - <project name>` task if there is one (first build vs delta). An unreadable source is named with the missing access and skipped.
2. **Draft facts** per `references/format.md`: one sentence, one tag, one citation, an as-of date. Unclear → ⚠️ Partial; a gap → ❓ Missing; two sources that disagree → a conflict with both citations for the PM to settle.
3. **Re-run** → a delta, never a rewrite: changed / new / now-confirmed facts, touching only the subtasks whose sections changed.

## From a call

One meeting (a Fathom link or name, or an uploaded transcript). Asked for decisions or tasks with no Profile → say this and stop:

```output
Can't extract — no Project Profile for this project. Run raftkit-pm:profile first, then re-run.
```

Read at once the whole transcript, the Profile and the workspace members, then draft per `references/call.md`: cited decisions, SCOPE CHANGE flags, action items, the Profile delta (⚠️ unless decided unambiguously on the call) and a task batch. Nothing found → say so and create nothing.

## Stop once

Show the draft as it will be written (lists, never tables), the project as `<name> (gid)`, and every subtask or task to be created or overwritten. The PM may approve parts: "delta yes, tasks except #3."

```output
Profile draft for Riverside Bookings (1216…). 4 subtasks, 38 facts: ✅ 21 / ⚠️ 12 / ❓ 5. 2 conflicts.
**STOP** — approve to write, edit to change, or decline.
```

**On go**, write the approved parts; read back once. A timed-out write is looked up by name before any retry. Report:

```output
38 facts — ✅ 21 / ⚠️ 12 / ❓ 5. Top gaps: payment provider, refund window.
Profile lives at: <link>
```

A call run also lists each created task's link and anything left unassigned.

- **Announce it** — `Using raftkit-pm:profile` in the first reply, once (`raftkit-core:rules`).
