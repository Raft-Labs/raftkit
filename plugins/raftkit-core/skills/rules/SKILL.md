---
name: rules
description: The RaftKit rules every role skill inherits — Asana GIDs, the Project Profile convention, one human stop per run, fetch-once for live reads, the Asana HTML floor, free-tier limits, the scope line, founder escalation and the estimation watermark. Read once per session before any RaftKit skill acts; role skills never restate these.
user-invocable: false
---

# RaftKit rules

Every pm, dev and qa skill inherits these and never restates them.

## Constants — the only place GIDs live

| Constant | Value |
|---|---|
| Asana workspace | `1194107417268910` |
| Feature Template (stories) | `1216778429401199` |
| Bugs Template (bugs) | `1215260732424760` |
| Subtasks | `[AC] …` criteria, plus `Development` / `Testing` / `Bugs` |
| Project Profile | task `Project Profile - <project name>` in that project, one subtask per section; read all |

Templates are read live by GID; this repo holds no template text. If one cannot be read, stop with this line and never use a remembered shape.

```output
Can't read the live template — check your Asana connector, then retry.
```

## Fetch once per run

Fetch the story, its `[AC]`s, the template and the profile once at the start and paste them into every subagent prompt; subagents inherit nothing. Reuse anything fetched earlier in this conversation unless you can no longer quote it verbatim. Re-read a task right before overwriting its description. Re-fetch a story's `[AC]`s once before auditing a diff.

## One stop per run

A run fetches, plans, builds and checks without waiting, then stops exactly once, before anything leaves the session: an Asana write, a PR, a Sheet write, a message. The stop shows the complete content, names every target, and ends on this line:

```output
**STOP** — approve to push, edit to change, or decline.
```

- An explicit go pushes exactly what was shown. An edit is not a go: re-present the changed draft. A reply that only chooses among options the draft itself listed is a go, and pushes with those choices. Silence pushes nothing.
- A run that writes nothing has no stop.
- Merging a PR, ticking `[AC]` or `Testing`, and closing a bug stay human.
- Comments by default; overwrite a description only on explicit instruction. Read the result back once and fold it into the success line. On partial failure, report what landed; retry only idempotent writes.

## Asana HTML floor

One `<body>` root; no `<p>`; attributes only on `<a>`; escape `&` `<` `>`; no named entities. Details: `references/asana-html.md`.

## Free tier only

No dependencies, custom fields, milestones, start dates or approval tasks. Relationships are task links.

## Scope is a hard line

The story's `[AC]`s define done. A diff beyond them is flagged, never quietly kept; improvements become board proposals. A missing requirement goes back through `raftkit-pm:story` amend mode, whose comment CCs every follower; a dev-answerable gap is cleared by the dev and logged on the story in the same run. Project facts live in the Project Profile, never in a plugin.

## Never invent

Every claim traces to a supplied source or a live fetch. A gap is asked in one batched question, never guessed. Profile beats other sources; any other conflict stops and is named. Readiness: `references/readiness.md`.

## Founders decide money and commitments

Budget, contracts, relationship risk and anything a client could read as a commitment go to Nirav or Ashit. Every numbered estimate opens with `Requires founder review — not a client commitment.` and travels AI → the developer who will build it → a founder → the client.

## New skills

Suggest with provenance → human approves → install.

## Plain output

Short sentences, active voice, numbers not adjectives, end on the next action: `references/plain-language.md`.

## Telemetry

Claude Code reports itself through hooks; no skill does anything. Cowork has no hooks and emits no event when a skill runs, so a pm or qa skill names itself once in its first reply — `Using <plugin>:<skill>`. That line is the whole difference — no skill calls an endpoint, spools a file, or reports anything itself. `RAFTKIT_TELEMETRY=off` is a Claude Code switch and does nothing in Cowork; there is no per-session equivalent. Contract — `skills/cowork-telemetry/SKILL.md`.
