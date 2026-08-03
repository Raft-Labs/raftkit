---
name: pr
description: This skill should be used when a RaftLabs developer wants to raise a pull request the house way — e.g. "raise the PR", "open a PR for this story", "run the pr skill", or when /implement reaches its final step after scope-guard is clean. It raises ONE squash-target PR (never main directly) with a commitlint-valid title (the future squash commit = the changelog line) and a description carrying the five mandatory sections (story link, AC checklist, out-of-scope confirmation, test summary, Docs result), then runs pr-review-toolkit and addresses or explicitly answers every finding before a human reviewer is requested. It refuses on an empty branch or while scope-guard flags are open, and surfaces a pre-push hook failure verbatim. It NEVER merges and never approves its own PR — merging is human-only.
user-invocable: true
---

# pr

Raise one story's PR to house conventions with the automated review already
addressed, so human reviewers spend their attention on judgment, not on
checklists. The release-train rule is absolute: **1 PR = 1 squash commit = 1
changelog line = 1 QA item = 1 clean revert** (PRD §5.3). The PR **title is the
changelog line** — commitlint-valid or the train rejects it.

This skill is the final step of `/implement` and also runs standalone. It
orchestrates existing engines — scope-guard, the pre-push hook, pr-review-toolkit
— and rebuilds none of them.

## The one rule that governs everything

**The skill raises and requests review — it never merges and never approves its
own PR.** Merging, promoting, and tagging belong to a human and to the
release-train automation. This holds even when every gate is green: a clean PR is
handed to a human, never self-merged.

## Preconditions — a gate chain, checked in order, before raising

Each is a hard stop with a fixed message; do not raise until all pass.

1. **Commits exist.** Diff the branch against the resolved squash target. If there
   are no commits beyond the target, refuse — exact string:

   ```
   nothing to raise — branch has no commits beyond target
   ```

2. **scope-guard is clean.** The PR is blocked while scope is open. **Run
   `raftkit-dev/scope-guard` and require its clean-pass line** — a standalone run
   invokes it; an `/implement` run may reuse the Gate 2 result if it is still fresh
   for this branch. Proceed only when it reports the line **verbatim**:

   ```
   Scope-guard: clean — 0 beyond, 0 missing
   ```

   Any BEYOND or MISSING item ⇒ refuse and point at the open flags; do not raise a
   PR over an unresolved scope audit. (scope-guard owns that line — check it, never
   re-derive it.)

3. **A commitlint-valid title.** Validate the title before raising; an invalid
   title blocks the raise and gets a compliant proposal (see
   `references/raise-flow.md`). Never raise on a failing title.

If any precondition cannot be evaluated (no story in hand, unreadable diff), stop
and say which — never raise against a guessed target.

## Run flow

Work `references/raise-flow.md` then `references/automated-review.md` in order.

1. **Resolve constants + read the story live.** Get the workspace GID from
   `raftkit-core/workflow-constants`; fetch the story and its `[AC]` subtasks live
   (never from memory or this repo) — they populate the AC checklist and the
   out-of-scope confirmation.
2. **Resolve the squash target** by the documented order (repo docs → release-train
   doc default → refuse). Never target `main` directly, never hardcode a branch
   name. See `references/raise-flow.md`.
3. **Run the precondition gate chain** above.
4. **Build the title** — conventional-commit form, the changelog line for this
   story; propose a compliant one if the draft fails (`references/raise-flow.md`).
5. **Build the description** — the five mandatory sections, all named and present:
   story link · AC checklist · out-of-scope confirmation · test summary · Docs
   (the verified docs result or evidence-backed no-impact — a missing or empty
   Docs section blocks the raise) (`references/raise-flow.md`).
6. **Push + raise.** The push runs the repo pre-push hook; if it rejects, surface
   the failing layer **verbatim** (spec / lint / typecheck / tests) and stop — never
   bypass with `--no-verify`. Then open the PR against the squash target, assigning
   reviewers from CODEOWNERS when present; when absent, leave reviewers unset and
   note it in the run output.
7. **Automated review before humans.** Run pr-review-toolkit (always); address
   or explicitly answer every finding, then request the human reviewer with the
   success line (`references/automated-review.md`):

   ```
   automated layers clean — requesting human review
   ```

8. **Close the loop** per `raftkit-core/write-protocol` (draft → approve): tick the
   story's `Development` subtask complete AND comment the PR link on the story task.
   These two are the only Asana writes; `[AC]`/Testing ticks and the merge stay
   downstream human gates.

## Guardrails

- **Never merge, never approve its own PR** — human-only, always.
- **Never target `main` directly** — only the resolved squash target.
- **One PR per story** — stacked PRs are out of scope in v1.
- **Never bypass the pre-push hook** — no `--no-verify`; a hook failure is surfaced
  verbatim and stops the raise.
- **Story read live, not cached** — the AC checklist and out-of-scope confirmation
  come from the live Asana fetch every run.
- **Automated layers before humans** — a human reviewer is requested only after
  pr-review-toolkit findings are addressed or answered.
- **Escalate to founders** per `raftkit-core/house-rules` if the PR implies a
  budget, contract, or client-relationship risk beyond the code.

## Out of scope

- **Merging, promoting, or tagging** — release-train automation and a human own
  those; this skill raises and requests review only.
- **Configuring the CI quality guardrail or the pre-push hook** — owned by
  `raftkit-dev/setup-project`; `pr` only *surfaces* the hook's result, never
  installs or edits it.
- **Stacked / multi-story PRs** — one branch = one story = one PR in v1.
- **Code-quality judgments, including the SOLID/design-pattern bar** — owned
  by `simplify`, pr-review-toolkit (scored against
  `raftkit-core/design-standard` when installed), and `implement`'s
  design-review layer; `pr` orchestrates those layers, it does not
  second-guess them.

## Reference files

- `references/raise-flow.md` — squash-target resolution order and refusal string,
  the empty-branch and scope-guard gates, commitlint title validation with a
  compliant proposal, the five mandatory description sections, CODEOWNERS
  reviewers, and the verbatim pre-push-failure surfacing.
- `references/automated-review.md` — pr-review-toolkit (always, scoped to an
  explicit merge-base range), the address-or-answer-before-humans gate, the
  success line, and the never-merge/never-approve guardrail.


## Asana rendering

All Asana output is rendered and verified through core `asana-formatting` (per-surface tag matrix, markdown→HTML conversion, mentions, read-back verification), behind the `write-protocol` draft → approve → push gate.
