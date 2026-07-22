# Validate before handover, and regenerate on change

An emitted skill is only worth delivering if it produces a template-perfect story. This
file defines the gate that proves that before handover, and the flow for replacing a skill
when the project's context moves.

## The pre-delivery validation gate

Before declaring a freshly emitted `<project>-user-story` skill ready:

1. **Check the package shape.** The emitted artifact is a SKILL.md plus `references/`
   carrying the bundled source snapshots, and every snapshot opens with its as-of date and
   source URL — or source location, when the original is not linkable
   (`references/baked-context.md`). A missing snapshot, or one without its
   header, blocks handover before any story is run.
2. **Run one validation story.** Use **the exact skill under test** to generate a story into a
   **scratch task** — a throwaway target, never a real client story — so nothing real is touched.
   The scratch task is created draft → approve like any Asana write. On a first generation the
   skill under test is the just-emitted skill; on a regeneration it is the **candidate
   specifically** (by its distinct staging identity), never a co-resident prior version. Confirm
   the story was produced by the skill under test before trusting the result.
3. **Check the connector budget.** During the validation run, the only live calls are the
   Feature Template fetch and the scratch task's own Asana calls. Any Drive / Gmail / Fathom
   read for project content is a failed gate — it means the snapshots are incomplete and the
   token-efficiency promise is broken. Fix the bundle, not the story.
4. **Compare against the live template.** Fetch the live Feature Template
   (`raftkit-core/workflow-constants`) and check the validation story matches it: every
   template section present, the WEESLD rows covered, and the `[AC]` / `Development` /
   `Testing` / `Bugs` subtasks shaped per the conventions.
5. **Divergence blocks handover.** If any section of the validation story diverges from the
   template — or the package shape or connector budget fails — the skill is **NOT delivered**.
   Report **which check or section diverged** (name it),
   fix the emitted skill, and regenerate — then re-run this gate. Fail closed: anything you
   cannot confirm matches is a divergence, not a pass.
6. **Show the PM the result** either way — the validation-story link and the pass/blocked
   verdict — before declaring the skill ready. Silence is not a pass. Once the PM confirms
   the result, **delete the scratch task** — it is a throwaway, not a record.

## Regeneration — replace, never fork

When the project's sources or profile change materially, the PM re-runs the generator
against the updated approved profile:

1. **Re-derive** the four baked elements from the new profile, and **re-snapshot every
   source** with fresh as-of dates and source URLs.
2. **Build the replacement as a candidate under a distinct staging identity — do not touch the
   live skill yet.** Emit the new version to a separate name/location (e.g.
   `<project>-user-story-candidate`) so it is unambiguously distinct from the still-live
   `<project>-user-story`; the delivered skill keeps working until the replacement is proven.
3. **Validate the candidate through the gate above** — run the validation story with the
   **candidate specifically** (by its staging identity), never the co-resident live skill, vs
   the live template. **Divergence blocks the swap** — the current skill stays in place,
   unreplaced. Never overwrite a working skill with one that has not passed validation.
4. **Show the baked-context diff and the validation result** — what changed in the glossary,
   roles, and conflict hierarchy versus the current skill, which snapshots were refreshed
   (old → new as-of dates), plus the pass verdict —
   so the PM sees exactly what the update moves and that it validated.
5. **Get explicit approval before replacing.** Follow `raftkit-core/write-protocol`
   (draft → approve → write): wait for the PM to approve the overwrite. Silence is not approval
   — never replace an already-delivered skill unasked.
6. **Promote the validated candidate into place** under the `<project>-user-story` name,
   overwriting the incumbent and removing the staging copy — only after the candidate passes
   validation **and** the PM approves. Regeneration **replaces, never forks** — there is only
   ever one current skill per project once promotion completes. Bump the version and re-stamp
   the profile's as-of date.
