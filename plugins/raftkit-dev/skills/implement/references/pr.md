# The PR

Target the squash target resolved at intake, never `main`; one PR per story, never stacked. A standalone raise first runs `raftkit-dev:scope-guard`, `verify.mjs` and `validate-docs.mjs` on the pinned base, and proceeds only when scope-guard is clean or lists only signed-off items.

**Title**: `type(scope): summary`, imperative, no trailing period, within the repo's commitlint header length or 100 characters. Never raise a failing draft: propose a compliant one and say why.

**Description**: six sections, all present, under the repo's PR template headings when it has one.

1. **Story link**, plus the permalink of any clarification logged this run.
2. **Acceptance criteria** as a checklist, from the live story.
3. **Out of scope**, each item confirmed not built.
4. **Tests**, generated from the plan table: each `[AC]` with its test file and result, then what else ran, and `[AC]s with tests n/m`.
5. **Docs**: the `raftkit-dev:docs` result verbatim, with the change set it inspected. `Docs: not evaluated` blocks the raise.
6. **Review findings**: one line per finding, `fixed in <sha>` or `answered — <reason>`, or `none`.

Incident path: sections 1 to 3 become the incident source with its raw artifact, the containment scope and the regression test. A branch with neither a story nor an incident trace is not raisable.

**Push**: never `--no-verify`. A pre-push rejection quotes the failing output verbatim and stops the raise. Reviewers come from CODEOWNERS; with none, say so.

**Close-out**: tick `Development` and comment the PR link. A failed write leaves the PR standing: give the story URL, the PR URL and the tick to do.

**Bug path**: section 2 is the bug's `Done when` checklist; the close-out is `fix`'s hand-back and `Fixed in build` edit, no tick.

```output
nothing to raise — branch has no commits beyond target
```
