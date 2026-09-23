# The review pass

One pass, on the final diff, mostly in parallel. It runs after the phases are green and before the stop.

## Dispatch

Every Agent call passes `model` for its tier (`raftkit-core:working-agreement` → `references/tiers.md`): a phase at its own tier; the simplifier and the reviewers at `sonnet`, raised only for a finding that needs more.

## Order

1. **Simplify first**, alone: dispatch `pr-review-toolkit:code-simplifier` with `model: "sonnet"` across the branch diff only. Its findings are triaged by `references/simplify.md`. Re-run the suite after the pass; a red test reverts the change that caused it before the fan-out starts. This runs first so the reviewers judge the diff that will actually ship.
2. **Then the fan-out**, all at once on the merge-base diff:
   - `pr-review-toolkit:code-reviewer` with `model: "sonnet"`, scored against the repo's `CLAUDE.md`, which carries the design standard.
   - `pr-review-toolkit:type-design-analyzer`, `pr-review-toolkit:silent-failure-hunter` and `pr-review-toolkit:pr-test-analyzer`, each with `model: "sonnet"`. Never through `review-pr`, which runs them one after another.
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

Every finding is fixed on the branch or answered in the PR's review-findings section with the reason no change is needed. Silence resolves nothing. A `scope-guard` flag is different: a BEYOND item blocks until it is removed or signed off by name, and a MISSING item until it is built or explained.

## Cost

Report the pass's token total at the stop, so an expensive run is visible rather than discovered later.
