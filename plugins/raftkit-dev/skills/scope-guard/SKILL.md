---
name: scope-guard
description: Audit a branch diff against its story — "run scope-guard", "check my diff against the story", "did I add anything beyond the story", "audit scope before the PR". Returns two lists, BEYOND THE STORY and MISSING FROM THE STORY, and a pass or block. Fail-closed. Reports only; never removes code, never judges quality.
user-invocable: true
---

# scope-guard

One branch, one story, two lists. `raftkit-core:rules` apply. `implement` and `fix` call this inside their review fan-out and pass the story, its `[AC]`s, the plan record and the diff straight in; a standalone run fetches them itself.

**Fail-closed and report-only.** Every changed hunk maps to an acceptance criterion or it lands in BEYOND. The audit lists and blocks; a human removes flagged code or signs it off.

## Inputs

The story and its `[AC]` subtasks including the out-of-scope section (matched on its heading, not a number), the plan record at `docs/specs/<branch>.md` when one exists, and the diff. Injected inputs are used as given and never re-fetched. Standalone: no story named → ask, never guess.

```output
Can't read the story — check your Asana connector, then retry.
```

An unusable git state stops with the exact remedy (`git status`, then `git switch <branch>`); a branch carrying more than one story's work is rejected by name, never audited.

## Audit

Anchor the diff at the merge-base with the branch the PR will target, fetching that branch first so changes landing on the base after the branch diverged are never blamed on it:

```
git fetch origin <base-branch>
git diff "$(git merge-base FETCH_HEAD HEAD)" HEAD
```

Walk it file group by file group. Each changed item is in scope when it maps to an `[AC]`, to a clarification recorded in the plan record, or to a documentation file that record lists. An item matching the story's out-of-scope list is an automatic BEYOND flag, not a judgment. Anything else is BEYOND. Then walk the other way: an `[AC]` with no corresponding change or test is MISSING. An empty diff is not a pass — every `[AC]` is MISSING.

## Output

```output
BEYOND THE STORY
MISSING FROM THE STORY
```

BEYOND names each item with its files. MISSING quotes each uncovered acceptance criterion verbatim. Both empty:

```output
Scope-guard: clean — 0 beyond, 0 missing
```

Otherwise the PR is blocked with the item counts. A BEYOND item clears by removal or by a logged sign-off naming the item, the reason and the developer; the item stays listed as signed off, never dropped. A MISSING item clears by being built or explained; when the story itself is wrong, the PM settles it through `raftkit-pm:story` amend.

This skill never judges code quality: that is the review fan-out. It never edits the diff.
