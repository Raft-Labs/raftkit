# Tiers

The vocabulary for the `tier` a plan names against each phase, and for the model a skill sets on each subagent it dispatches. Rule 1 of the working agreement decides which tier a piece of work belongs in; this file only fixes the names, so a phase table and a dispatch mean the same thing.

| Tier | Model | Work |
|---|---|---|
| `mechanical` | Haiku | Renames, moves, fixtures, log parsing, generated-file edits. |
| `standard` | Sonnet | Components, tests, single-file refactors, ordinary debugging. Reviewers default here. |
| `hard` | the session model | Cross-layer design, distributed-state bugs, anything the developer chose the session model for. |

A phase whose tier is unstated is `standard`.

## Reading, not writing

`bulk-reader` is the one dispatch that is not a phase: a Haiku subagent that answers a question from files too large to page into the session, and returns cited bullets instead of their contents. The `PreToolUse` shunt in `raftkit-core` names it when it declines an oversized read. It reports; it never edits, and it is never given a file that is itself an instruction to follow.
