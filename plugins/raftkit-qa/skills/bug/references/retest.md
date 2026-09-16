# Retest — pass list, build, outcomes

## The pass list

The whole definition of done, not the repro step:

- every `Done when` item, retested independently;
- every adjacent flow, role or plan the bug names, because a fix can pass its own list and break a neighbour.

Each item records pass or fail and, on fail, its evidence. `N` = `Done when` items, `M` = adjacent checks.

## Build and environment

The stated build (`Fixed in build ___`) in the stated environment (the bug's original unless QA names another). Never a different build.

## Pass (all green)

On go, post the comment below. Closing the task is QA's, by hand; the skill never changes completion state. Emit only after the write lands:

```output
Retest passed — all N done-when items + M regression checks green on build X. Close the bug.
```

## Fail (any item red)

Order is fixed: fresh evidence from this run (a new Jam link, or console and network errors quoted verbatim; never the original evidence reused) → failures itemised, each tied to its evidence → then the `Retest Failed` tag and the comment. The bug returns to the dev reopened; the refix is `raftkit-dev:fix`. Retest never decides the refix's priority.

The tag's name belongs to the project: resolve it at run time; if the project has none, propose creating `Retest Failed` in the stop message, or ask there which tag to use. A reopen that is not tagged is not counted. After the writes land:

```output
Retest Failed — K of N+M items red on build X; tagged, returned to dev.
```
