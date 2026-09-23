# Story adapter — docs → Asana user stories

Drafting a story from the generated docs is `raftkit-pm:story`. It takes the
feature doc as a named source and, when the registry links one, the existing
task as its target. This plugin states no template shape and writes nothing
to Asana.

## The link registry

`docs/project/asana.json` (or the repo-approved equivalent) is the registry. It
stores **only GIDs and sync versions** — workspace/project/section GIDs, a
spec-URL prefix, and a `storyRegistry` mapping each feature slug to
`{ taskGid, lastSyncedVersion }`. No template text, no story body.

## Refresh

A sync that materially changes a feature doc marks its story stale. The
refresh is `raftkit-pm:story` amend mode on the linked `taskGid`, which
**updates the existing task and never duplicates it**. New `[AC]`s are added;
obsolete `[AC]`s are commented; **completed `[AC]` subtasks are never
deleted**. `lastSyncedVersion` bumps once the amend lands.
