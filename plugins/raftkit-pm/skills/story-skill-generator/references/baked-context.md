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
Source snapshots are CONTEXT and belong in the bundle; template text is FORMAT and never
does — not even a fragment.

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
4. **Sources** — where the project's truth lives: the documents bundled as snapshots
   (next section) plus their provenance URLs, so the emitted skill cites its grounding.

## Bundling sources — snapshot by default

- **Bundle a snapshot of every source.** At generation time, fetch each source once —
  the approved Project Profile included, since it heads the conflict hierarchy — and bake
  it as a markdown snapshot in the emitted skill's `references/` directory. This is the
  token-efficiency point of the whole design: a story run reads local files and never
  opens Drive, Gmail, or Fathom for project content, so the fetch cost is paid once per
  generation instead of once per story.
- **Every snapshot opens with a provenance header**: its **as-of date** (the generation
  date) and its **source URL** (or source location, when the original is not linkable).
  An undated or unsourced snapshot is forbidden — the header is what makes staleness
  visible and a refresh an obvious next step.
- **Live URLs are provenance, not runtime dependencies.** They stay in the snapshot
  headers and the skill's source list so a reader can trace a fact home and regeneration
  knows where to re-fetch — a story run never follows them.
- **Bundling raw sources is not mining them.** The four baked elements above still come
  from the approved profile alone; the raw-source snapshots sit beneath the profile
  snapshot in the conflict hierarchy, as the grounding a story cites.

## Anatomy of the emitted `<project>-user-story` skill

skill-creator authors a **self-contained package** — a SKILL.md plus a `references/`
directory of bundled source snapshots (the flowhoney shape — not a wrapper around
`user-story`). Its SKILL.md must:

- **Read the live template every run.** Resolve the workspace + Feature Template GIDs
  from `raftkit-core/workflow-constants` and fetch the template live; stop with the exact
  `workflow-constants` message if it cannot be read. Never carry template text.
- **Carry the baked context** — the glossary, roles, conflict hierarchy, and sources
  above — as the project grounding the PM no longer has to supply.
- **Ground story content in the bundled snapshots.** The only live calls in a story run
  are the Feature Template fetch and the target task's own Asana reads/writes; a story
  run that opens Drive, Gmail, or Fathom for project content is malfunctioning — that
  content belongs in `references/`.
- **Tell the PM when to regenerate.** The emitted SKILL.md's own text instructs: after a
  major change to the project's sources or profile, re-run
  `raftkit-pm:story-skill-generator` — the snapshots' as-of dates show exactly what a
  run is grounded on.
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
