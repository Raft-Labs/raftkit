# Story structure — mirror the live template, derive the subtasks

The generated story must match the **live** User Story Template exactly. The
template is fetched fresh every run (see `raftkit-core/workflow-constants`); it is
the sole authority for structure. Never reproduce a section list from memory —
read it off the freshly fetched template each time.

## Mirror the template exactly

- Reproduce the **header block** and **every numbered section** the fetched
  template contains, in the same order, with the **same numbers and titles** —
  including any gap in the numbering (if the template skips a number, skip it too;
  do not renumber to make it contiguous).
- Follow the template's own instructions for what each section holds. Replace
  every placeholder with a real, sourced value; leave nothing as a `{...}`
  placeholder and never substitute "add appropriate text".
- The template's **comments** (fill guide + worked example) are guidance for
  drafting only. They are never copied into the story.
- If the template's structure changed since the last run, the new structure is
  reproduced automatically — that is the point of reading it live.

## Task name vs. story title

- The **task name** = a short area name (what the task is about at a glance).
- The **full imperative title** lives in the `STORY:` header line inside the body,
  not in the task name.

## Derive the `[AC]` subtasks

Acceptance criteria are the **subtasks**, one independently verifiable behaviour
per line, each named with the `[AC] ` prefix. They map 1:1 to tests. Cover, at
minimum:

- **The happy path** — the main success behaviour.
- **Every WEESLD edge state** present in the story — Waiting, Empty, Error,
  Success, Limits, Default values. The **Error** state is mandatory: it states the
  exact message the user sees and the recovery action.
- **Every business rule** — each non-negotiable rule becomes its own verifiable
  criterion.
- **Every permission boundary** — who is allowed and, explicitly, who is blocked
  (enforced server-side, not merely hidden in the UI).

## Always add the fixed subtasks

In addition to the `[AC]` subtasks, always create three plain subtasks:
`Development`, `Testing`, and `Bugs`. These are the RaftKit subtask conventions
(see `raftkit-core/workflow-constants`) and are added on every story.

## Writing to Asana

- Write the body as `html_notes`. `raftkit-core/write-protocol` is the single
  authority for the Asana HTML rules — apply them from there; do not restate them.
- Create the `[AC]` and `Development`/`Testing`/`Bugs` subtasks after approval.
- Free tier only: express any relationship (a depends-on story, an epic link) as a
  task link in the description — never as an Asana dependency, custom field, or
  milestone.
