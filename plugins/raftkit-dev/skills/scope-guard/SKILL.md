---
name: scope-guard
description: This skill should be used when a RaftLabs developer wants to audit a branch diff against its story before opening a PR — e.g. "run scope-guard", "check my diff against the story", "did I add anything beyond the story", "audit scope before the PR", or when /implement reaches its pre-PR gate (Gate 2). Reads the story and its live [AC] subtasks plus the Out-of-scope section from Asana, diffs the branch against the merge-base with the PR base branch, and returns exactly two lists — BEYOND THE STORY (additions with no AC, and any Out-of-scope item that appears) and MISSING FROM THE STORY (an AC with no change or test, quoted). Fail-closed — anything it cannot map to an AC lands in BEYOND for a human call. It reports and blocks only — it never removes code and never judges code quality (simplify, CodeRabbit, and pr-review-toolkit own that).
user-invocable: true
---

# scope-guard

Audit one branch's diff against one story, so the diff never exceeds or
undershoots the story. The output is exactly two lists — **BEYOND THE STORY**
and **MISSING FROM THE STORY** — and a block/pass verdict. Both empty is a pass;
anything on either list blocks the PR until a human resolves it.

This is the hard scope line at AI velocity (PRD §5.3, §7.1): additions sneak in
and ACs get dropped without anyone deciding it. scope-guard makes both visible
and blocking, at Gate 2 of `/implement` and on demand at any point.

## The one rule that governs everything

**Fail-closed, and report-only.** Two halves, both non-negotiable:

1. **Fail-closed.** Every changed hunk must map to an `[AC]` or it lands in
   BEYOND — an unmappable change is a human call, never a silent pass. The
   default is to flag, not to excuse.
2. **Report and block — never remove, never judge quality.** scope-guard lists
   and blocks; a human removes flagged code or signs it off. It does not delete
   code, and it does not assess code quality — that is `simplify`, CodeRabbit,
   and pr-review-toolkit (Out of scope, below).

And a flagged item may only survive with the dev's **explicit, logged sign-off**
— **silence is not approval**. The sign-off log format is in
`references/output-and-signoff.md`.

## Preconditions — check before auditing

1. **One target story.** The audit is against a single story's ACs. From
   `/implement` the story is in hand; standalone, take the task link/GID or the
   board task name. No story given → **stop and ask**; never audit against a
   guessed target.
2. **One story per branch.** The release train is 1 branch = 1 story
   (`raftkit-core` release model). If the branch carries more than one story's
   work, **reject the run** naming the collision — do not audit a multi-story
   branch (see `references/audit-method.md`).
3. **A reachable diff.** The branch must diff against its base. If git is in a
   detached or otherwise unusable state, **stop with the exact git remedy** in
   `references/output-and-signoff.md` — do not audit a partial diff.

## Run flow

1. **Resolve constants and read the story live.** Get the workspace GID from
   `raftkit-core/workflow-constants`, then fetch the target story **and all its
   `[AC]` subtasks** live via the Asana connector — every run, never from memory
   or this repo. Read the story's "Out of scope / non-goals" section in the
   same fetch (match on the heading, not a section number — the template's
   numbering is not stable). If the story cannot be read, **stop and name the access problem**
   using the `workflow-constants` stop message — do not audit against a
   remembered or partial story (Error state; `references/output-and-signoff.md`).
2. **Take the diff.** Diff the branch against the **merge-base with the PR base
   branch** — the same anchor the repo's `validate.sh` version gate uses, so the
   audit sees exactly the branch's own changes. Large diffs are walked
   **file-group by file-group with progress** so nothing is skipped
   (`references/audit-method.md`).
3. **Audit into the two lists** (`references/audit-method.md`):
   - **BEYOND THE STORY** — every changed item (feature, field, screen, file)
     that maps to no `[AC]`, **each listed with its files**; plus any item that
     matches the story's **Out-of-scope** list — those are automatic BEYOND
     flags, a fail condition, not a judgment.
   - **MISSING FROM THE STORY** — every `[AC]` with no corresponding change or
     test, **the uncovered AC quoted verbatim**.
   - Fail-closed: anything that cannot be mapped to an AC lands in BEYOND.
4. **Verdict** (`references/output-and-signoff.md` for the exact strings):
   - **Both lists empty** → emit the clean-pass line and mark the PR unblocked.
   - **Either list non-empty** → block. A BEYOND item clears only by removal or
     an explicit logged sign-off; a MISSING item clears only by being built or
     explained. Report the outcome with the item counts.

## Guardrails

- **Fail-closed** — unmappable changes land in BEYOND for a human call; the
  audit never excuses what it cannot map.
- **Report and block only** — never remove flagged code, never auto-fix; the
  human removes or signs off.
- **Silence is not approval** — a BEYOND item survives only with a logged
  sign-off naming the item, the reason, and the dev (`references/output-and-signoff.md`).
- **Story read live, not cached** — the ACs and the Out-of-scope list come from
  the live Asana fetch every run, never from this repo.
- **Diff anchored at the merge-base** with the PR base branch — matches the
  `validate.sh` version-gate anchor; never audit against a stale local base.
- **One branch = one story** — a multi-story branch is rejected, not audited.
- **Escalate to founders** per `raftkit-core/house-rules` if a flagged item
  implies a budget, contract, or client-relationship risk beyond scope itself.

## Out of scope

- **Code-quality judgments** — readability, duplication, style, security review.
  Those are `raftkit-dev/simplify`, CodeRabbit, and pr-review-toolkit; scope-guard
  only checks the diff against the story's ACs.
- **Auto-removing flagged code** — scope-guard reports and blocks; a human
  removes or signs off. It never edits the diff.

## Reference files

- `references/audit-method.md` — mapping the diff to ACs, the Out-of-scope
  auto-BEYOND rule, the fail-closed default, large-diff file-group walking, and
  the multi-story-branch rejection.
- `references/output-and-signoff.md` — the exact two-list output, the fixed
  headers and clean-pass line, the block semantics, the sign-off log format, and
  the error states (story unreachable, diff unavailable) with their git remedy.
