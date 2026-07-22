# Validate before handover, and regenerate on change

An emitted skill is only worth delivering if it produces a template-perfect story. This
file defines the gate that proves that before handover, and the flow for replacing a skill
when the project's context moves.

## The pre-delivery validation gate

Before declaring a freshly emitted `<project>-user-story` skill ready:

1. **Run one validation story.** Use **the exact skill under test** to generate a story into a
   **scratch task** — a throwaway target, never a real client story — so nothing real is touched.
   On a first generation that is the just-emitted skill; on a regeneration it is the **candidate
   specifically** (by its distinct staging identity), never a co-resident prior version. Confirm
   the story was produced by the skill under test before trusting the result.
2. **Compare against the live template.** Fetch the live Feature Template
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
2. **Build the replacement as a candidate under a distinct staging identity — do not touch the
   live skill yet.** Emit the new version to a separate name/location (e.g.
   `<project>-user-story-candidate`) so it is unambiguously distinct from the still-live
   `<project>-user-story`; the delivered skill keeps working until the replacement is proven.
3. **Validate the candidate through the gate above** — run the validation story with the
   **candidate specifically** (by its staging identity), never the co-resident live skill, vs
   the live template. **Divergence blocks the swap** — the current skill stays in place,
   unreplaced. Never overwrite a working skill with one that has not passed validation.
4. **Show the baked-context diff and the validation result** — what changed in the glossary,
   roles, conflict hierarchy, and source links versus the current skill, plus the pass verdict —
   so the PM sees exactly what the update moves and that it validated.
5. **Get explicit approval before replacing.** Follow `raftkit-core/write-protocol`
   (draft → approve → write): wait for the PM to approve the overwrite. Silence is not approval
   — never replace an already-delivered skill unasked.
6. **Promote the validated candidate into place** under the `<project>-user-story` name,
   overwriting the incumbent and removing the staging copy — only after the candidate passes
   validation **and** the PM approves. Regeneration **replaces, never forks** — there is only
   ever one current skill per project once promotion completes. Bump the version and re-stamp
   the profile's as-of date.
