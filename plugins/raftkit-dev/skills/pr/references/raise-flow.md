# Raise flow — target, gates, title, description, push

The mechanical path from a story branch to an open PR. Everything here runs
before automated review (`automated-review.md`). Refusal strings are **fixed** —
emit them verbatim.

## Resolve the squash target (never main, never hardcoded)

The PR targets the repo's documented squash target, resolved live in this order:

1. **Repo docs.** A branching/release doc or `CLAUDE.md` in the repo that names
   the integration branch (e.g. `development`, `nightly`, `develop`). Use what the
   repo documents.
2. **Release-train doc default.** If the repo docs are silent, fall back to the
   release-train doc (`raftkit-core/workflow-constants` holds its task GID) and use
   the target it names.
3. **Refuse.** If neither names one, stop — do not guess, do not target `main`:

   ```
   no documented squash target — name one in the repo docs
   ```

Never target `main` directly and never bake a branch name into the skill — the
target is data read at run time.

## Gate 1 — commits exist

Diff the branch against the resolved target (`git log <target>..HEAD`,
`git rev-list --count <target>..HEAD`). Zero commits beyond the target ⇒ refuse:

```
nothing to raise — branch has no commits beyond target
```

## Gate 2 — scope-guard is clean

The PR is blocked while scope is open. **Run `raftkit-dev/scope-guard`** and
require its clean-pass line **verbatim** before proceeding (a standalone run
invokes it; an `/implement` run may reuse the Gate 2 result if it is still fresh
for this branch):

```
Scope-guard: clean — 0 beyond, 0 missing
```

Any BEYOND or MISSING item ⇒ refuse and point at the open flags (name the item and
the list it is on). scope-guard owns this line and its two-list output — check for
the clean line, never re-derive the audit here.

## Gate 3 — commitlint-valid title (propose, don't just reject)

The title is the future squash commit and therefore the changelog line, so it must
pass conventional-commit / commitlint rules **before** the PR is raised:

- Shape: `type(scope): summary` — `type` one of the conventional set
  (`feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `build`, `ci`, `perf`,
  `style`, `revert`); `scope` optional; a non-empty imperative summary; the header
  within the max length (read from the repo's commitlint config when present, else
  the commitlint default of 100 chars); no trailing period.
- The summary reads as a changelog line for the story (what shipped, not "WIP").

If the draft title fails, **do not raise**. Propose a compliant title derived from
the story title and branch, show why the draft failed, and require a passing title
before raising. Rejecting without a proposal is not enough.

## Build the description — five mandatory sections, all named

The description template is fixed; every section is present and labelled:

1. **Story link** — the Asana story URL/permalink (read live this run).
2. **AC checklist** — every `[AC]` subtask from the live story, as a checklist.
3. **Out-of-scope confirmation** — the story's Out-of-scope items, each confirmed
   not built (mirrors the scope-guard audit).
4. **Test summary** — what was tested and the result (the gates that ran, the ACs
   walked).
5. **Docs** — the story's documentation result, carried from `raftkit-dev:docs`
   verify: the updated files with their verification result, or the
   evidence-backed `Docs: not impacted — <reason>` line (the owner's string,
   reproduced, with its inspected change set). Never fabricate a docs result to
   fill the section.

A missing or empty section is a fail — do not raise a PR with an incomplete body.

## Push + raise

- **Push runs the pre-push hook** (owned by `setup-project`: spec / lint /
  typecheck / tests). Never bypass it (`--no-verify` is forbidden). If the hook
  rejects the push, **surface the failing layer's output verbatim** — do not
  paraphrase, summarise, or hide which layer failed — and stop. `pr` surfaces the
  hook result; it never installs or edits the hook (that is `setup-project`).
- **Open the PR** against the resolved squash target with the validated title and
  the five-section body (GitHub tooling / `gh pr create`).
- **Reviewers** default to the repo's CODEOWNERS when present; when absent, leave
  reviewers unset and note it in the run output. Honour existing branch protections.

One PR per story — stacked / multi-story PRs are out of scope in v1.
