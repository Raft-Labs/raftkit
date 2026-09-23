---
type: llm
weight: 1
---

# Grading criteria — linked-story-refresh

The story is amended in place: additive, never a rewrite.

## PASS if all of the following hold

- The draft amends the existing task 1216559988771234; no second task is proposed for the feature.
- It is a diff: untouched sections listed, each changed section shown as its current text then its replacement, and the new `[AC]`s in full, one verifiable behaviour each (shared search links, and who is blocked from opening one).
- The two completed `[AC]`s are untouched: not deleted, not unticked, not reworded.
- The obsolete CSV-export `[AC]` is not deleted or reworded; dropping it is offered as a board proposal, since removing agreed scope is not an edit.
- The follower comment is drafted in full and closes with one `CC:` line mentioning both followers.
- Nothing is claimed as written; the parent story is never marked complete.

## FAIL if any of the following occur

- A second task is created or proposed for the feature.
- Any `[AC]` is deleted, unticked or silently reworded, or a section is removed or renumbered.
- The description is rewritten wholesale instead of shown as a diff.
- The mid-build warning is missing even though `Development` is ticked.
