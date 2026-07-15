# Validate before handover, and regenerate on change

An emitted skill is only worth delivering if it produces a template-perfect story. This
file defines the gate that proves that before handover, and the flow for replacing a skill
when the project's context moves.

## The pre-delivery validation gate

Before declaring a freshly emitted `<project>-user-story` skill ready:

1. **Run one validation story.** Use the emitted skill to generate a story into a **scratch
   task** — a throwaway target, never a real client story — so nothing real is touched.
2. **Compare against the live template.** Fetch the live User Story Template
   (`raftkit-core/workflow-constants`) and check the validation story matches it: every
   template section present, the WEESLD rows covered, and the `[AC]` / `Development` /
   `Testing` / `Bugs` subtasks shaped per the conventions.
3. **Divergence blocks handover.** If any section of the validation story diverges from the
   template, the skill is **NOT delivered**. Report **which section diverged** (name it),
   fix the emitted skill, and regenerate — then re-run this gate. Fail closed: anything you
   cannot confirm matches is a divergence, not a pass.
4. **Show the PM the result** either way — the validation-story link and the pass/blocked
   verdict — before declaring the skill ready. Silence is not a pass.

## Regeneration — replace, never fork

When the project's sources or profile change materially, the PM re-runs the generator
against the updated approved profile:

1. **Re-derive** the four baked elements from the new profile.
2. **Show the baked-context diff** — what changed in the glossary, roles, conflict
   hierarchy, and source links versus the previously generated skill — so the PM sees
   exactly what the update moves.
3. **Replace** the existing `<project>-user-story` skill in place. Regeneration **replaces,
   never forks** — there is only ever one current skill per project.
4. **Bump the generated skill's version** and re-stamp the profile's as-of date.
5. **Re-validate** the replacement through the gate above before delivering it.
