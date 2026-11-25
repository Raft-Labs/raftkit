---
name: rules
description: The rules every RaftKit role skill loads first — Asana constants, one stop per run, fetch once, free tier, scope line, founders and the estimate watermark.
user-invocable: false
---

# RaftKit rules

Every role skill inherits these; none restates them.

## Constants — the only place GIDs live

- Asana workspace: `1194107417268910`
- Feature Template (stories): `1216778429401199`
- Bugs Template (bugs): `1215260732424760`
- Subtasks: `[AC] …` criteria, plus `Development` / `Testing` / `Bugs`
- Project Profile: task `Project Profile - <project name>` in that project, one subtask per section

Read templates live by GID; never use a remembered shape. One unreadable → stop:

```output
Can't read the live template — check your Asana connector, then retry.
```

## Fetch once per run

Fetch the story, its `[AC]`s, the template and the Profile sections the run uses once, at the start; reuse a fetch while you can still quote it verbatim. Re-read a task right before overwriting its description. Re-fetch a story's `[AC]`s once before a scope audit. Fields and batching: `references/asana-calls.md`.

## One stop per run

A run works without waiting, then stops once before anything leaves the session: an Asana write, a PR, a Sheet write, a message. The stop shows the complete content and every target, and ends on:

```output
**STOP** — approve to push, edit to change, or decline.
```

- Before any read, confirm a tool exists for every write the run needs. One missing → the first reply is this, and nothing is read:

```output
Can't write to <surface> from this session — connect <connector>, then re-run.
```

- An explicit go pushes exactly what was shown; choosing among options the draft listed is a go. An edit re-presents only the changed sections. Silence pushes nothing.
- A run that writes nothing has no stop.
- Merging a PR, ticking `[AC]` or `Testing`, and closing a bug stay human.
- Comments by default; overwrite a description only on explicit instruction.
- Read the result back once into the success line. The write response is the read-back when it returns the rendered body.
- On partial failure, report what landed; retry only idempotent writes.

## Asana HTML floor

One `<body>` root; no `<p>`; attributes only on `<a>`; escape `&` `<` `>`; no named entities. Details: `references/asana-html.md`.

## Free tier only

No dependencies, custom fields, milestones, start dates or approval tasks. Relationships are task links.

## Scope is a hard line

The story's `[AC]`s define done. Flag any diff beyond them; improvements become board proposals. A missing requirement goes back through `raftkit-pm:story` amend; the dev clears a dev-answerable gap and logs it on the story. Project facts live in the Project Profile, never in a plugin.

## Never invent

Every claim traces to a supplied source or a live fetch. Ask gaps in one batched question; never guess. The Profile wins; name any other conflict and stop. Readiness: `references/readiness.md`.

## Founders decide money and commitments

Budget, contracts, relationship risk and anything a client could read as a commitment go to Nirav or Ashit. Every numbered estimate opens with `Requires founder review — not a client commitment.` and travels AI → the developer who builds it → a founder → the client.

## Plain output

Short sentences, active voice, numbers not adjectives, no filler; end on the next action. Never show `WEESLD`; name the edge-case row.

## Telemetry

In Cowork a pm or qa skill names itself once in its first reply: `Using <plugin>:<skill>`. No skill reports anything else; Claude Code uses hooks.
