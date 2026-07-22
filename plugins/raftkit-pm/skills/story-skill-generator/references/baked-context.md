# What to bake, and what to emit

The generator's whole value is a clean split: bake the project's **context** so the PM
never re-feeds it, and leave the story **format** to the live template so it never goes
stale. This file defines both sides of that split and the shape of the skill that comes
out the other end.

## The CONTEXT / FORMAT boundary

- **CONTEXT — bake it.** What is true about *this project* and stable run to run: its
  vocabulary, its people, its rules of precedence, its sources. Baking this is the point.
- **FORMAT — never bake it.** The Feature Template: section list, WEESLD rows, `[AC]`
  and `Development` / `Testing` / `Bugs` subtask conventions. This lives in Asana, changes
  there, and is read **live** by GID (`raftkit-core/workflow-constants`) every run. A baked
  format is a stale format shipped silently.

If a candidate fact would change when the template changes, it is FORMAT — do not bake it.

## The four baked elements

Extract these from the approved Project Profile — and only from it. Do not mine raw
sources directly; the profile is the vetted, approved distillation.

1. **Glossary** — the project's domain terms and their meanings, so the emitted skill
   writes stories in the project's own vocabulary without the PM re-explaining it.
2. **Roles** — who is allowed / not allowed to do what (the permission boundaries the
   story's "Who is allowed / not allowed" line draws on).
3. **Conflict hierarchy** — which source wins when sources disagree (e.g. Project Profile
   → then sources that agree → else stop and ask). The emitted skill applies this exact
   order when grounding a story.
4. **Source links** — where the project's truth lives, so the emitted skill cites its
   grounding.

## Citing sources — live URL over snapshot

- **Prefer the live URL.** Wherever a source is linkable (a Drive doc, a board, a spec
  page), bake the **URL**, not its contents — the emitted skill cites the live source and
  never carries a copy that can rot.
- **Snapshot only when unavoidable.** If a source genuinely cannot be linked, bake a
  minimal snapshot and stamp it with its **as-of date**, so its staleness is visible and a
  refresh is an obvious next step. An undated snapshot is forbidden.

## Anatomy of the emitted `<project>-user-story` skill

skill-creator authors a **self-contained** skill (the flowhoney pattern — not a wrapper
around `user-story`). Its SKILL.md must:

- **Read the live template every run.** Resolve the workspace + Feature Template GIDs
  from `raftkit-core/workflow-constants` and fetch the template live; stop with the exact
  `workflow-constants` message if it cannot be read. Never carry template text.
- **Carry the baked context** — the glossary, roles, conflict hierarchy, and source links
  above — as the project grounding the PM no longer has to supply.
- **Inherit the stop-and-ask rules verbatim.** Copy them from the current
  `raftkit-pm/user-story` SKILL.md ("The one rule that governs everything" + its guardrails) —
  read that skill at generation time and copy exactly, never a remembered paraphrase, so the
  rules never drift from the generic skill: never proceed without the source of truth, never
  invent or placeholder a fact, and stop and ask — naming what is missing or which sources
  conflict — on a missing/thin source or a conflict the hierarchy cannot resolve. Verbatim, so
  both skills behave identically here.
- **Be named and versioned** — `<project>-user-story`, stamped with the as-of date of the
  profile it was generated from. The first generation is `v1`; regeneration bumps from there
  (see `references/validation-and-regeneration.md`).
