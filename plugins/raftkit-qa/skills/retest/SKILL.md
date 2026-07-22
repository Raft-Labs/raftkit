---
name: retest
description: This skill should be used when a RaftLabs QA engineer wants to retest, re-test, verify, or re-check a returned bug fix in Asana — e.g. "retest this bug", "the dev says it's fixed in build 42, verify it", "re-check bug X on the fix", "close it if the fix holds". Reads the live Bugs Template from Asana as the format authority, builds a retest sheet from the bug's full "Done when" checklist plus adjacent regressions, and runs it on the stated build in the bug's stated environment. All items green closes the bug with a build-named comment; any failure applies the project's Retest Failed tag with fresh evidence and itemized failures and returns the bug to the dev. To file a new bug use file-bug; the refix itself is raftkit-dev's fix-bug.
user-invocable: true
---

# retest

Verify a returned fix, then take one of two disciplined outcomes: **close it**
(the fix is verified) or **tag Retest Failed and send it back with fresh
evidence** (the reopen is tracked, not relitigated). A bug closes only when its
whole definition-of-done passes — the full "Done when" checklist and the
regressions around it, not just the one step that first broke.

This packages the dev-environment-free QA retest loop (PRD §5.4): QA retests from
the bug's own checklist and every reopen is measured (PRD §8 reopen-rate metric).

## The one rule that governs everything

**Evidence before tag.** The project's **Retest Failed** tag is *never* applied
without fresh evidence attached — a new Jam link, or the errors quoted verbatim —
plus which "Done when" items failed. This is the core guarantee: a reopen always
carries proof, so "still broken" is never a bare assertion. The full ordering and
format are in `references/tag-and-evidence.md`.

It rests on two standing house rules this skill inherits, both non-negotiable:

1. **The live Bugs Template is the only format authority.** Read it live every
   run (run flow step 1); never work from a remembered or repo-cached shape.
2. **Draft → approve → push.** Only QA closes a bug, and no close, tag, or
   comment reaches Asana without QA's explicit approval of the draft — per
   `raftkit-core/write-protocol`. The skill drafts; QA approves; only then does
   anything reach Asana.

And never fabricate: evidence is quoted **verbatim**, never paraphrased. When a
required input is missing, stop and ask — naming exactly what is missing.

## Preconditions — check before building a retest sheet

1. **One target bug.** Retest runs on a single bug (see Guardrails, one bug per
   run). No bug given → **stop and ask**; never retest a guessed target.
2. **A build to test against.** The bug must carry **"Fixed in build ___"** filled
   by the dev. Missing → **bounce to the dev unretested** with the exact message
   in `references/retest-run.md`; no retest runs. The retest contract — the
   story's — requires a build; there is nothing to verify without one.
3. **A "Done when" checklist.** The checklist is the retest contract. A bug with
   none is **routed back through file-bug discipline** (`raftkit-qa/file-bug`) —
   the checklist is added there, then retest re-runs. See `references/retest-run.md`.

## Run flow

1. **Resolve constants and fetch the live template.** Get the workspace GID and
   the Bugs Template GID from `raftkit-core/workflow-constants`, then fetch that
   template task live via the Asana connector — every run, never from memory or
   this repo. Its section structure and field labels are the format authority for
   reading the bug this run. If it cannot be read, stop with the exact
   `workflow-constants` message; do not fall back to a remembered format.
2. **Read the target bug live** and confirm the two gates above: "Fixed in
   build ___" is filled (else bounce, step 2 of Preconditions) and a "Done when"
   checklist exists (else route to file-bug, step 3). One bug only.
3. **Fix the build and environment.** Retest runs on the **stated build** in the
   bug's **stated environment**; environment defaults to the bug's original one.
   If the stated build is unavailable in that environment, **bounce with the exact
   message naming build + environment** (`references/retest-run.md`) — do not
   silently retest a different build.
4. **Build the retest sheet.** From the bug's **full "Done when" checklist** plus
   **adjacent-regression items** — the other roles, plans, or flows the bug names.
   This is the whole pass list; the original repro step is one item among it, never
   the whole test. Details and the item shape in `references/retest-run.md`.
5. **Walk every item on the stated build** (guided manual), recording pass/fail
   per item and capturing evidence as you go.
6. **Take the outcome** (`references/retest-run.md` for the exact strings):
   - **All items green** → **close**: post the verbatim confirmation comment
     naming the build, then close the bug. Only QA closes.
   - **Any item fails** → **fail path** (`references/tag-and-evidence.md`): gather
     fresh evidence + the itemized failures **first**, then draft the Retest Failed
     tag application, comment, and return-to-dev — reopened and tracked. This feeds
     the reopen-rate metric; the refix itself is the dev's `fix-bug` loop (M3).
7. **Draft → approve → push.** Show the drafted close comment, or the fail comment
   plus the tag to apply, and name the exact target bug. On approval, write —
   applying the Asana HTML rules from `raftkit-core/write-protocol`; if a push is
   rejected, fix the HTML per those rules, **retry once**, then surface the error.
8. **Confirm back** in one line: closed on build X, or Retest Failed applied and
   the bug returned to the dev with the count of failed items.

## Guardrails

- **Evidence before tag** — the Retest Failed tag is never applied without fresh
  evidence + itemized failures (the core guarantee; `references/tag-and-evidence.md`).
- **Only QA closes bugs.** A fix handed back without "Fixed in build ___" is
  bounced to the dev unretested — the skill refuses to retest it.
- **Retest is the whole checklist.** The full "Done when" list plus adjacent
  regressions, on the stated build in the bug's stated environment — never just the
  original repro step, never a different build.
- **Template read live, not cached.** The bug's section structure and field labels
  come from the live template fetch every run — never from this repo; the rationale
  for retesting the whole "Done when" checklist is the story's, not the template's
  (`references/retest-run.md`).
- **The Retest Failed tag is project-specific.** Resolve it at run time from the
  bug's project — never hardcode a tag name (the file-bug priority-tag pattern).
  If the project has no such tag, **create-or-ask, never fail silently**
  (`references/tag-and-evidence.md`).
- **One bug per retest run.** Each run's evidence, outcome, and comment attach to a
  single bug; batching would blur which evidence proves which reopen.
- **Asana free tier** per `raftkit-core/house-rules`: no dependencies, custom
  fields, milestones, start dates, or approval tasks; the Retest Failed tag is
  free-tier. Express relationships as task links.
- **Escalate to founders** per `raftkit-core/house-rules` if a reopen implies a
  budget, contract, or client-relationship risk beyond the defect itself.

## Out of scope

- **Fixing the bug** — that is `raftkit-dev`'s `fix-bug` loop (M3). Retest verifies;
  it never edits the fix.
- **Deciding the priority of the refix** — that is PM/dev triage, not retest.
- **Editing the Bugs Template itself** — it is read-only format authority here.

## Reference files

- `references/retest-run.md` — building the retest sheet ("Done when" + adjacent
  regressions), build/environment resolution and the unavailable-build bounce, the
  missing-build bounce, the file-bug route for a missing checklist, and the
  verbatim close comment.
- `references/tag-and-evidence.md` — the evidence-before-tag guarantee, the fresh-
  evidence format, the Retest Failed tag's run-time resolution and create-or-ask,
  and the reopen-and-return-to-dev loop that feeds the PRD §8 reopen-rate metric.


## Asana rendering

All Asana output is rendered and verified through core `asana-formatting` (per-surface tag matrix, markdown→HTML conversion, mentions, read-back verification), behind the `write-protocol` draft → approve → push gate.
