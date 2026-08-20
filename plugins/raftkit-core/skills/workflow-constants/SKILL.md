---
name: workflow-constants
description: This skill should be used whenever a RaftKit skill needs a workflow constant — the Asana workspace GID, the Feature or Bugs template task GID, the subtask naming conventions, or the Project Profile task convention that tells every skill how to find a project's profile — or must fetch a live template from Asana. Consult it before reading, creating, or formatting any Asana task, and before reading a Project Profile, even when the constant is not named explicitly. It is the single source of these identifiers; never guess them or reuse remembered template content.
user-invocable: false
---

# RaftKit Workflow Constants

This is the one place RaftKit stores the identifiers every role plugin (pm / dev / qa) needs to reach the shared Asana workspace and its format-authority templates. It stores **GIDs only** — never the contents of a template. Storing GIDs and fetching live is what stops the templates in Asana and the copies in code from drifting apart: there is only ever one copy, and it lives in Asana.

## The constants (v1)

| Constant | GID / value |
|---|---|
| Asana workspace | `1194107417268910` |
| Feature Template (format authority) | `1216778429401199` |
| Bugs Template (format authority) | `1215260732424760` |
| Subtask conventions | `[AC] …` acceptance criteria, plus `Development` / `Testing` / `Bugs` |
| Project Profile task | Task named `Project Profile - <project name>`, in the project it describes, carrying one subtask per profile section |

Read template GIDs from this table — never hardcode them into a skill's own instructions.

## Resolving a constant

To use a constant, read its value from the table above. That is the whole resolution step — the values are static identifiers, not content.

## Finding a project's Project Profile

A profile is not a document at a path. It is one Asana task in the project it
describes, carrying one subtask per section, written by
`raftkit-pm project-onboarding`. Every skill that reads a profile finds it the
same way — no skill asks a human where it lives:

1. Find the task named `Project Profile - <project name>` in that project.
2. Read **all** of its subtasks. A profile carries only the sections its sources
   support, so the set varies by project — never look up a section by name and
   never assume a particular one exists.

**No such task** — that project has no profile. Do not invent one, and do not
carry on with house defaults as though none was expected: say so, and route to
`raftkit-pm project-onboarding` to build it first.

## Fetching a template (happy path)

Templates carry the required format for user stories and bug reports. That format is authored and maintained in Asana, so it must be read live every run:

1. Resolve the template GID from the table above.
2. Fetch the LIVE task from Asana by that GID through the Asana connector.
3. Use the freshly fetched task as the format authority for this run.

Never reuse a template's body from memory, from an earlier run, or from anywhere in this repo. A remembered format is a stale format, and shipping a stale format silently is exactly the failure this design exists to prevent.

## When something is missing or unreachable

**A required constant is missing or unset** — stop, and name the specific constant that is missing. Do not substitute a plausible-looking GID or proceed on a guess; a wrong workspace or template GID corrupts real client work.

**raftkit-core is not installed** — a role plugin cannot resolve any of these constants without core. Stop with this exact message:

```output
raftkit-core is required — install it from the raftkit marketplace.
```

**The live template cannot be read** (Asana connector down, no access, or the task is unreachable) — stop with this exact message, and do not fall back to a remembered format:

```output
Can't read the live template — check your Asana connector, then retry.
```

Falling back to remembered content here would hide the outage and produce a story or bug report in an outdated shape — worse than stopping, because no one would know to fix it.

## Guardrails

- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.
