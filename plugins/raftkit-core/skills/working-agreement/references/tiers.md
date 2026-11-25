# Tiers

The vocabulary for the `tier` a plan names against each phase, and for the `model` a skill passes on each subagent it dispatches. Rule 1 of the working agreement decides which tier a piece of work belongs in; this file only fixes the names, so a phase table and a dispatch mean the same thing.

| Tier | Agent `model` | Work |
|---|---|---|
| `mechanical` | `haiku` | Renames, moves, fixtures, log parsing, generated-file edits. |
| `standard` | `sonnet` | Components, tests, single-file refactors, ordinary debugging. Reviewers, the simplifier and the Explore survey. |
| `hard` | the session model's alias, or `opus` under `opusplan` | Cross-layer design, distributed-state bugs, anything the developer chose the session model for. |

A phase whose tier is unstated is `standard`.
