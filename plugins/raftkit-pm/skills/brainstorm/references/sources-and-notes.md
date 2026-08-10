# Sources and notes — look before asking, and remember across sessions

Nothing here is a source of project facts. It is the procedure for finding
them, and for carrying what was settled into the next session. Where those
things live is a **parameter** the person supplies or the Project Profile
holds — never a folder, project, or client named in this file
(`raftkit-core/house-rules`).

## Starting from a project name alone

A project name with nothing attached is a complete starting point. Do not ask
for documents before looking for them.

Check in this order, and stop early when what you have is enough:

1. **Session notes for this project.** What earlier sessions already settled.
   Read these first — they are faster than re-deriving, and they stop the
   person re-explaining what they already explained. Anything recorded here
   counts as settled context; build on it rather than re-verifying it.
2. **Asana.** Search the workspace from `raftkit-core/workflow-constants` for a
   task or project matching the name. Pull the task, its full description, and
   its comment history — decisions often live only in comments.
3. **The project's document store.** Search for files or folders matching the
   name. Its root is a parameter, so ask for it the first time and reuse what
   the person gives you. Take whatever is there: specs, proposals, transcripts,
   screenshots, quotes.

The store is reachable by whatever path the session offers — a connector, an
upload, a pasted link, or a synced local folder. Accept whichever path exists;
never insist on one.

## Report what turned up, then move

One line per source. Not a dump of what is inside them.

```output
Found it.
Asana — one task, 7 comments.
Drive — 6 files: spec, proposal draft, screens walkthrough, 3 more.
No earlier notes, so this is the first session on it.
```

Then start. Do not summarise every document before the conversation begins;
build enough understanding to ask good questions, and pull detail as it is
needed.

## When nothing turns up

Say so plainly and ask for whatever exists. Never require all of it — take what
the person has.

```output
Couldn't find "<name>" in Asana or the project folder.
Share whatever you have — a task link, a folder, an email thread, or
just tell me about it. Any one of those is enough to start.
```

If a search using a supplied parameter finds nothing twice, the parameter is
probably wrong. Ask for the correct workspace or folder rather than guessing
again.

## Handling a source that will not open

Name the exact source and the exact access that is missing, carry on with the
ones that do open, and list the skipped ones in the result. A source is never
dropped silently.

## Notes across sessions

Sessions end. The next one should not start from zero.

**Where they live is a parameter.** Ask the person the first time, then reuse
it. It may be the Project Profile's home, a document store folder, or a synced
file — the rule is only that the skill never picks it silently and never
hardcodes it. The Project Profile home is still an open decision on the board,
so treat it the same way `project-onboarding` does.

**Offer, never save silently.** Saving notes is an outward write, so it goes
through `raftkit-core/write-protocol` like everything else: show what would be
saved, name where it lands, wait for a yes. Offer at natural checkpoints and at
the end of a session — not after every message.

**Overwrite in full.** There is no partial patch. The notes are a snapshot of
current state plus a history line, and a half-updated snapshot is worse than a
stale one.

What a notes file holds:

- Settled facts and decisions, each dated, tagged ✅ Confirmed / ⚠️ Partial /
  ❓ Missing as in `interview-map.md`
- Assumptions still standing, and what would confirm each
- Open questions with their triage label — must-ask, good-to-clarify, or the
  team decides
- Recommendations made, and whether the person took them
- One line saying what this session covered, so the next session sees the
  history and not only the latest state

**Next session, read them first.** Live sources may have moved since, so check
those too — but read the notes before re-scanning, and never re-ask what they
already answer.

## When it is a whole project, not a feature

Sometimes the scan turns up a project's worth of material — a spec, a contract,
months of email. Turning that into one tagged source of truth is
[`project-onboarding`](../../project-onboarding/SKILL.md)'s job, not this one.
Offer it, then carry on with the feature in front of you. Do not build a
Project Profile here.
