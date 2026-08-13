# Scaffolding — optional bootstrap, always asked

Phase 12 is optional and only ever offered after refinement. The rule that
governs it: **always ask before running anything that touches the filesystem
outside docs.** Every command is named to the developer before it runs.

## Flow

1. Offer the archetype-matched bootstrap (the exact CLI from
   `stack-and-domain-recipes.md`), or a hand-rolled setup document when no
   recipe fits. Ask the scaffold questions under the normal interview contract
   — no exception here, because the approval gate above is per command, not per
   question.
2. Run the approved bootstrap. Show what it created.
3. Post-scaffold, propose (each its own approval):
   - environment setup via the project's env mechanism;
   - the project-local docs companion (`assets/companion/`) — its
     installation and activation across agent runtimes is owned by
     setup-project's delivery seam, never performed here ad hoc;
   - supporting capabilities — every install routes through
     capability-preflight readiness and setup-project's approved
     transactional install; this skill proposes, it never installs;
   - copying `assets/templates/` into the project's docs tree as its local
     template set;
   - the first commit and CI wiring.

## Never auto-run

These are never executed without a fresh, explicit, per-action approval:

- `db:push` or any schema push that bypasses migrations — always
  migration-based.
- Any push to main.
- Cloud resource creation without the profile/account named and confirmed.
- Mobile release builds.

## Boundaries

Scaffolding never bypasses setup-project's governance-pack install, never
modifies global or system configuration, and never proceeds past a failed
step — a partial scaffold is reported exactly as far as it got, with the
recovery options.
