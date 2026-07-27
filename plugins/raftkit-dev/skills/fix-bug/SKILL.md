---
name: fix-bug
description: This skill should be used when a RaftLabs developer is handed a templated Asana bug task to fix — e.g. "fix this bug", "run fix-bug on <bug-url>", "work this bug ticket", or when a bug is assigned and needs a defect turned into a failing regression test and then fixed to green. It reads the bug task live from Asana, reproduces the defect as a FAILING test BEFORE any fix is written by wrapping superpowers:systematic-debugging (the order is enforced — no red test, no fix), then fixes to green on a branch through the same scope-guard → simplify → commit → squash-PR loop as feature work, fills "Fixed in build ___" on the bug task, and hands back to QA. It bounces bugs missing steps or environment back to QA naming the exact missing template sections, and returns cannot-reproduce bugs with what was tried, the environment used, and one focused question — it never fixes blind. Not for filing bugs (raftkit-qa file-bug), retesting fixes (raftkit-qa retest), or production incidents (fix-production-error).
user-invocable: true
---

# fix-bug

Take one templated bug task, reproduce it as a **failing test**, fix to green, and
hand back to QA with `Fixed in build ___`. Bugs go through the **same gated loop as
features** — the only difference is where the loop starts: from a red repro test,
not from a story's ACs.

This is PRD decision #19: **TDD applies to all dev work, bugs included.** The Bug
Template's environment and steps exist precisely so a failing test can be written
first (PRD §5.3). A bug fixed without a repro test can silently return; a bug fixed
after a repro test cannot.

This skill **orchestrates** — it rebuilds nothing. It wraps
`superpowers:systematic-debugging` for the reproduce-and-diagnose work,
`superpowers:test-driven-development` for the red-before-fix order, and
`superpowers:verification-before-completion` for the evidence gate at hand-back,
and reuses the sibling skills `raftkit-dev/scope-guard` (the BEYOND audit) and
`raftkit-dev/simplify` (the minimalism pass). Reach for them by name.

## The one rule that governs everything

**Red before fix — no failing repro test, no fix. And the repro test stays in the
suite permanently.**

Two halves, both non-negotiable:

1. **Order is enforced.** The defect must be captured as a **failing** test that
   replicates it from the templated steps, in the bug's stated environment, and the
   test must be observed red **before a single line of fix is written**. There is no
   path in this skill that reaches the fix before the test is red.
2. **The repro test is permanent.** Once green, it is committed and stays in the
   suite forever as a regression guard — never deleted after the fix lands. This is
   the whole point: the same bug can never silently come back.

Everything else in this skill serves that order. The mechanics are in
`references/fix-loop.md`.

## Preconditions — check before touching anything

1. **One bug per run.** The Bug Template rule is one bug per ticket; this skill
   fixes one bug per run. If the task bundles unrelated defects, stop and ask which
   one — do not batch.
2. **The bug task is readable.** Resolve the workspace GID from
   `raftkit-core/workflow-constants` and fetch the bug task **and the live Bugs
   Template** (GID from `workflow-constants`) via the Asana connector — every run,
   never from memory or this repo. If the task or template cannot be read, stop with
   the exact `workflow-constants` failure lines; do not fix against a remembered
   shape.
3. **Steps, environment, and "Done when" are present.** The template's Steps to
   Reproduce and Environment blocks are the repro contract; its "Done when"
   checklist is the scope contract the fix is audited against. If any of the three
   is missing, **do not fix** — bounce the bug back to QA naming the exact missing
   template sections. See `references/bug-intake-and-handback.md`. The template is
   the contract both ways. (Match sections by their heading — the template's
   numbering is provisional and not stable.)
4. **A clean working tree on the bug's branch.** Feature-branch conventions apply
   (below). If the tree is dirty, stop and ask.

## Run flow

1. **Intake.** Read the bug task against the live Bugs Template. Confirm the
   Environment, Steps to Reproduce, and "Done when" sections are all present. Any of
   the three missing → bounce to QA (precondition 3). Read the environment from the
   Environment block — this is the environment the repro runs in.
   `references/bug-intake-and-handback.md`.
2. **Reproduce as a failing test — first.** Following
   `superpowers:systematic-debugging`, replicate the defect from the templated
   steps in the stated environment, and write a test that fails on it per
   `superpowers:test-driven-development` (red first).
   - **Test observed red** → continue.
   - **Cannot reproduce** → return the bug to QA with what was tried, the
     environment used, and **one** focused question — never fix blind
     (`references/bug-intake-and-handback.md`).
3. **Fix to green.** Only now, implement the smallest fix that turns the red test
   green, on the branch. If the fix turns **any other test red**, that is a **hard
   stop — fix-first**: never ship a fix that breaks another test
   (`references/fix-loop.md`).
4. **Scope-guard the fix diff.** Scope is the bug's "Done when" checklist and
   nothing else. Run the sibling `raftkit-dev/scope-guard` against the diff; anything
   it flags **BEYOND** is removed or explicitly signed off. Do not reinvent the
   audit — scope-guard owns it.
5. **Simplify.** Run the sibling `raftkit-dev/simplify` for a behaviour-preserving
   minimalism pass on the fix diff.
6. **Commit and open the PR** per the shared git conventions (below).
7. **Fill "Fixed in build ___" — mandatory before hand-back.** Write the build /
   version into the bug task's "Done when" section. This is the retest contract; QA cannot
   retest without it. Gate the claim with `superpowers:verification-before-completion`
   — observe the green run before asserting it — then hand back with the success
   line (`references/bug-intake-and-handback.md`).

## Git conventions (same as feature work)

Bugs use the same loop as feature implementation — expressed as the shared
`raftkit-core` release-train conventions:

- one feature branch for the bug fix;
- small, conventional commits (`fix:` for the fix itself);
- one **squash** PR, whose title reads as a changelog line;
- **human merge** — the skill never merges.

The repro-test commit and the fix commit both land on that branch; the repro test
is part of the permanent diff.

## Guardrails

- **Red before fix** — the order is enforced; no repro-red, no fix. The core
  guarantee (`references/fix-loop.md`).
- **Repro test is permanent** — committed and kept as a regression guard, never
  deleted after green.
- **Never fix blind** — cannot-reproduce returns to QA with tried steps, the
  environment used, and one focused question; it is never guessed at.
- **Environment is the bug's, not the dev's** — the repro runs in the environment
  the Environment block states, never the developer's local assumption.
- **Bounce on a broken contract** — a missing Environment, Steps to Reproduce, or
  "Done when" section goes back to QA naming the exact missing sections, before any
  fix.
- **Scope = "Done when" only** — adjacent changes are `scope-guard` BEYOND flags,
  removed or signed off; the fix never expands past the "Done when" list.
- **Breaking another test is a hard stop** — fix-first; a fix that reddens the
  suite never ships.
- **Fixed-in-build is mandatory** — the hand-back is blocked until the "Done when"
  section's `Fixed in build ___` is filled.
- **Read live, never cache** — the bug task and the Bugs Template are fetched live
  every run; this repo holds zero template text.
- **Escalate to founders** per `raftkit-core/house-rules` if a fix touches budget,
  contract, or client-commitment surface area.

## Out of scope

- **Filing bugs** — that is `raftkit-qa/file-bug`.
- **Retesting a fix** — that is `raftkit-qa/retest`; this skill hands back, QA
  retests.
- **Production incidents** — that is the `fix-production-error` skill (a sibling in
  this same `raftkit-dev` plugin); this skill is for templated bug tasks, not live
  incidents.

## Reference files

- `references/bug-intake-and-handback.md` — reading the live Bug Template's
  Environment, Steps to Reproduce, and "Done when" sections + `Fixed in build ___`; the
  environment-default rule; and both hand-back protocols (missing-sections bounce,
  cannot-reproduce return) with their exact wording.
- `references/fix-loop.md` — the red-before-fix mechanics, the permanent repro test,
  the `superpowers:systematic-debugging` → `scope-guard` → `simplify` orchestration seam, the
  git conventions, and the fix-breaks-another-test hard stop.
