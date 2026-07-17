# Bug intake and hand-back

The live Bugs Template (GID from `raftkit-core/workflow-constants`) is this skill's
**input contract**, and it is the contract **both ways** — the dev reads the same
sections QA is required to fill, and bounces the bug back the moment one the fix
depends on is absent. Read the template live every run; hold no template text in
this repo.

## The sections the fix depends on

Match on the section's **heading**, not its number — the template's numbering is
not stable. The three load-bearing sections:

- **Environment** — every field the live template's Environment block lists. This
  is the environment the repro test runs in.
- **Steps to Reproduce** — the deterministic steps the repro test replicates.
- **"Done when"** (the template's acceptance-criteria block) — the checklist that
  **defines the fix's scope**, plus the `Fixed in build / version ___` field the dev
  fills before hand-back.

## Environment default — the bug's, never the dev's

The repro runs in the environment the Environment block states. If it names Staging
on a given build and OS, the repro targets that — **never** the developer's local
machine as a silent substitute. A fix "verified" in the wrong environment is the
exact failure the Environment block exists to prevent ("still broken after the
fix"). If the stated environment cannot
be stood up, that is a cannot-reproduce hand-back (below), not a quiet switch to
local.

## Hand-back 1 — missing contract sections (bounce before any fix)

The fix depends on three sections: Environment and Steps to Reproduce (the repro
contract) and "Done when" (the scope contract the diff is audited against). If any
is missing or empty, **do not attempt a fix.** Bounce the bug to QA, naming the
**exact** template sections that are missing so QA knows precisely what to add:

```
Can't start the fix — the bug task is missing <Environment | Steps to Reproduce |
"Done when" | the relevant combination>. The Bug Template needs <that section /
those sections> filled before a failing repro test can be written and its fix
scoped. Back to QA to complete it.
```

Name the section(s) by their template heading. The template is the contract both
ways: QA fills it, the dev holds them to it.

## Hand-back 2 — cannot reproduce (never fix blind)

If the steps do not reproduce the defect in the stated environment, **return the
bug to QA — do not fix blind.** The return carries exactly three things:

1. **What was tried** — the steps followed and the observations, streamed as they
   were attempted (the Waiting state: repro attempts are visible, not silent).
2. **The environment used** — the stated environment the attempt ran in, named
   explicitly so QA can line it up against theirs.
3. **One focused question** — exactly one, the single thing most likely to unblock
   reproduction (e.g. a missing precondition, an unclear step, a data-state detail).
   Not a list; one question.

```
Can't reproduce in the stated environment.
Tried: <steps followed + what was observed>
Environment used: <the environment the bug task stated>
One question: <the single thing most likely to unblock repro>
Back to QA.
```

## Filling "Fixed in build ___" — mandatory before hand-back

Once the fix is green and the PR is open, write the build / version into the "Done
when" section's `Fixed in build / version ___` field on the bug task. This is the retest contract —
QA cannot retest a fix without knowing the build it landed in, so the hand-back is
**blocked** until this field is filled. Then hand back with the success line:

```
Red → green: repro test added, fix in PR #n, Fixed in build X — back to QA
```

## Asana write rules

Every write to the bug task (the `Fixed in build` fill, the hand-back comment) goes
through `raftkit-core/write-protocol`: draft → approve → push. Apply the Asana HTML
rules — single body root, no `<p>` (use line breaks), attributes only on `<a href>`,
escape `&`/`<`/`>`, and no named entities (write literal characters). This skill
never auto-writes; a human approves each write.
