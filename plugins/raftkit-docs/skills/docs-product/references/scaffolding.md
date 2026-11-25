# Scaffolding (phase 12, optional)

Offer it only after refinement. Name every command before it runs. Ask before touching anything outside docs. Questions follow `interview.md`; approval is per command.

1. Offer the chosen archetype's official bootstrap CLI, or a hand-written setup doc when none fits.
2. Run the approved bootstrap. Show what it created.
3. Propose each of these as its own approval:
   - environment setup through the project's env mechanism;
   - the docs companion (`assets/companion/`), rendered by `scripts/render-companion.mjs` — this plugin installs it, never `raftkit-dev:setup`;
   - supporting capabilities, every install through `raftkit-dev:setup`; this skill proposes, never installs;
   - copying `assets/templates/` into the project's docs tree;
   - the first commit and CI wiring.

## Never auto-run

Each needs a fresh, explicit, per-action approval:

- a schema push that bypasses migrations;
- any push to main;
- cloud resources without the named, confirmed account;
- mobile release builds.

## Boundaries

Never bypass `raftkit-dev:setup`'s governance pack. Never change global or system config. Never continue past a failed step: report a partial scaffold exactly as far as it got, with the recovery options.
