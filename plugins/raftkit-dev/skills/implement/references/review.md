# The review pass

One pass, on the final diff, mostly in parallel. It runs after the phases are green and before the stop.

## Order

1. **Simplify first**, alone: dispatch `code-simplifier:code-simplifier` across the branch diff only. Its findings are triaged by `references/simplify.md`. This runs before the fan-out so the reviewers judge the diff that will actually ship.
2. **Then the fan-out**, all at once on the merge-base diff:
   - `pr-review-toolkit`'s `code-reviewer` (scored against the repo's `CLAUDE.md`, which carries the design standard), `type-design-analyzer`, `silent-failure-hunter`, `pr-test-analyzer` — dispatched by their scoped names, in parallel. Do not route through `review-pr`, which runs them one after another by default.
   - `raftkit-dev:scope-guard`, given the story, the `[AC]`s, the plan record and the diff.
   - `raftkit-dev:docs`, given the same explicit change set.
   - Lint and the full test suite.
   - The security-guidance hook evidence already emitted during the edits. Nothing to invoke; never claim a review that did not run.

## Anchoring

Every reviewer sees the same range, never the tools' unstaged default, which is empty once the work is committed:

```
git fetch origin <squash-target>
git diff "$(git merge-base FETCH_HEAD HEAD)" HEAD
```

A reviewer reporting clean without naming a non-empty range reviewed nothing: treat that as a failed invocation.

## Findings

Every finding is fixed on the branch or answered in the PR description with the reason no change is needed. Silence resolves nothing. A `scope-guard` flag is different: a BEYOND item blocks until it is removed or signed off by name, and a MISSING item until it is built or explained.

## Cost

Reviewers run on Sonnet by default; raise the tier only for a finding that needs it. Report the pass's token total at the stop, so an expensive run is visible rather than discovered later.
