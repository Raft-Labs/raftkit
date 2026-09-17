# The PR

## Squash target

Resolved live, in order: the repo's own branching or release doc, then the release-train doc named in `raftkit-core:rules`. Neither names one → stop:

```output
no documented squash target — name one in the repo docs
```

Never target `main` directly, and never bake a branch name into this skill. One PR per story; stacked PRs are out of scope.

## Before the raise

The raise is blocked while scope is open. Inside a full run the review pass has already produced the verdict; a standalone raise runs `raftkit-dev:scope-guard` first and proceeds only on its clean line. Any BEYOND or MISSING item names the open flags and stops.

## Title

The title is the future squash commit and therefore the changelog line: `type(scope): summary`, conventional-commit type, imperative summary, no trailing period, within the repo's commitlint header length or 100 characters. A failing draft title is never raised — propose a compliant one, say why the draft failed, and use the approved one.

## Description — five sections, all present

1. **Story link**, plus the permalink of any clarification logged this run.
2. **Acceptance criteria** as a checklist, taken from the live story.
3. **Out of scope**, each item confirmed not built.
4. **Tests** — what ran and the result.
5. **Docs** — the result from `raftkit-dev:docs`, verbatim, with the change set it inspected. Never fabricated to fill the section. `Docs: not evaluated` blocks the raise the same way an empty section does: run the check with the real change set first.

An empty section blocks the raise, and so does `Docs: not evaluated` — run the check against the real change set first.

On the incident path there is no story: sections 1 to 3 become the incident source with its raw artifact, the containment scope as the change contract, and the permanent regression test. Nothing else downgrades — a branch with neither a story nor an incident trace is not raisable.

## Push

The push runs the repo's pre-push hook. Never `--no-verify`. A rejection surfaces the failing layer's output verbatim and stops the raise. Reviewers come from CODEOWNERS when the repo has them; when it does not, say so rather than guessing.

## Close-out

Two Asana writes, both in the one stop's draft: tick `Development`, and comment the PR link. `[AC]` and `Testing` ticks belong to QA, closing belongs to a human, and merging belongs to a human. If a write fails, the PR still stands: give the story URL, the PR URL and the tick to do by hand.

## Bug path

A `fix` run uses everything above with two changes, because a bug task has no acceptance criteria and no `Development` subtask. Section 2 of the description is the bug's `Done when` checklist instead of the acceptance criteria. The close-out is the hand-back comment plus the `Fixed in build` edit named in `fix`'s stop, and there is no tick.

## Nothing to raise

```output
nothing to raise — branch has no commits beyond target
```
