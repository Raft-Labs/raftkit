---
name: fix-bug
description: Use when a developer needs a defect fixed the house way — whether QA filed it as an Asana bug task ("fix this bug <url>", "work this bug ticket") or the dev found it themselves with no ticket at all ("I found a bug", "checkout is broken — fix it", "this is off by one, fix it properly", "the total is wrong, fix it with a regression test"). One gated loop, two intakes — a task-backed bug is read live against the live Bugs Template; a bug with no task is intaken in chat via four confirmed asks (environment, steps to reproduce, expected vs actual, "Done when"), so a missing ticket never blocks the fix. Either way the defect becomes a FAILING test before any fix is written, wrapping superpowers:systematic-debugging — no red test, no fix — then goes green through the same scope-guard → simplify → squash-PR loop as feature work. Not for filing bugs (raftkit-qa file-bug), retesting fixes (raftkit-qa retest), production stack traces (fix-production-error), or feature and refactor wishes (implement).
user-invocable: true
---

# fix-bug

Take one bug — from a templated Asana task **or** from the developer's own report —
reproduce it as a **failing test**, fix to green, and close the loop. Bugs go through
the **same gated loop as features**; the only difference is where the loop starts: from
a red repro test, not from a story's ACs.

**Two intakes, one loop.** QA-filed bugs arrive as a task and are read live against the
live Bugs Template. Bugs the dev found themselves arrive as their own report and are
intaken in chat. A dev is never blocked on not having a ticket — but the contract they
supply is held to the same bar, because the discipline is the whole reason to run this
skill instead of just patching the code.

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
   replicates it from the **confirmed** steps, in the stated environment, and the
   test must be observed red **before a single line of fix is written**. There is no
   path in this skill that reaches the fix before the test is red — on either intake.
2. **The repro test is permanent.** Once green, it is committed and stays in the
   suite forever as a regression guard — never deleted after the fix lands. This is
   the whole point: the same bug can never silently come back.

Everything else in this skill serves that order. The mechanics are in
`references/fix-loop.md`.

## Preconditions — check before touching anything

1. **One bug per run.** The Bug Template rule is one bug per ticket; this skill
   fixes one bug per run. If the task or the report bundles unrelated defects, stop and
   ask which one — do not batch.
2. **A defect contract exists — on one of two paths.** The path is decided on entry and
   the branch is deterministic (`references/bug-intake-and-handback.md`):
   - **Path A · task-backed** — a bug task **exists** (linked, or referenced and then
     linked on request). Resolve the workspace GID
     from `raftkit-core/workflow-constants` and fetch the bug task **and the live Bugs
     Template** (GID from `workflow-constants`) via the Asana connector — every run,
     never from memory or this repo. If the task or template cannot be read, stop with
     the exact `workflow-constants` failure lines; do not fix against a remembered
     shape.
   - **Path B · dev-reported** — **no task exists at all.** Gather the contract in chat
     via the **four asks**: Environment, Steps to Reproduce, Expected vs Actual, and
     "Done when". All four confirmed before any test; nothing inferred. This path reads
     **nothing from Asana at intake**, so neither a missing ticket nor an unreachable
     connector can block a dev who found the bug themselves.
3. **The contract is complete before any fix — how a gap is closed differs by path.**
   Environment and Steps to Reproduce are the repro contract; "Done when" is the scope
   contract the fix is audited against. All three are required on both paths; neither
   path reaches the fix on a half-known defect.
   - **Path A** — the three come from the template's own sections. If any is missing,
     **do not fix and do not ask the dev to fill it** — bounce the bug back to QA in the
     reference's **exact wording**, naming the missing template sections, posted as a
     comment on the task (draft → approve, per `raftkit-core/write-protocol`) so QA sees
     it on the record and not only in the dev's chat. The template is the contract both
     ways. (Match sections by their heading — the template's numbering is provisional
     and not stable.) Converting an incomplete task into a Path B run is the one
     substitution this skill forbids.
   - **Path B** — the three (plus Expected vs Actual) come from the four asks, and the
     run **stops** if the dev will not supply one; there is no inferred substitute.

   See `references/bug-intake-and-handback.md`.
4. **A clean working tree on the bug's branch.** Feature-branch conventions apply
   (below). If the tree is dirty, stop and ask.

## Run flow

0. **Triage — which path, or neither.** The test is whether a bug task **exists**, not
   whether a link was pasted: a task exists → **Path A**, so resolve it (ask for the
   link, or search Asana if it was described well enough to find); no task exists →
   **Path B**. An existing task that cannot be resolved either way is a **stop**, not a
   fall-through — withholding a link never buys the conversational intake. A **local,
   CI, or test-run** stack trace is an ordinary defect
   and belongs on the path its task status dictates. Two entries are refused rather than
   routed: a **production** stack trace or log → the sibling `fix-production-error`; a
   feature or refactor wish dressed as a bug → refused by name and routed to a story
   (`implement`) or a board proposal, because there is no wrong behaviour to make red.
   `references/bug-intake-and-handback.md`.
1. **Intake.**
   - **Path A** — read the bug task against the live Bugs Template. Confirm the
     Environment, Steps to Reproduce, and "Done when" sections are all present. Any of
     the three missing → bounce to QA (precondition 3).
   - **Path B** — make the four asks in one round, then confirm the set back before any
     test. Scope ("Done when") is **stated by the dev**; never draft it for them.

   Either way, the environment the repro runs in is the one that was **stated** — never
   an unnamed default. `references/bug-intake-and-handback.md`.
2. **Reproduce as a failing test — first.** Following
   `superpowers:systematic-debugging`, replicate the defect from the **confirmed**
   steps in the stated environment, and write a test that fails on it per
   `superpowers:test-driven-development` (red first).
   - **Test observed red** → continue.
   - **Cannot reproduce** → return what was tried, the environment used, and **one**
     focused question — never fix blind. Path A returns it to QA and stops; Path B asks
     the dev in session and resumes on their answer
     (`references/bug-intake-and-handback.md`).
3. **Fix to green.** Only now, implement the smallest fix that turns the red test
   green, on the branch. If the fix turns **any other test red**, that is a **hard
   stop — fix-first**: never ship a fix that breaks another test
   (`references/fix-loop.md`).
4. **Scope-guard the fix diff.** Scope is the bug's "Done when" checklist and
   nothing else — the task's on Path A, the dev's confirmed one on Path B, with
   identical force. Run the sibling `raftkit-dev/scope-guard` against the diff; anything
   it flags **BEYOND** is removed or explicitly signed off. Do not reinvent the
   audit — scope-guard owns it.
5. **Simplify.** Run the sibling `raftkit-dev/simplify` for a behaviour-preserving
   minimalism pass on the fix diff.
6. **Docs boundary.** A bug fix does not automatically rewrite product docs.
   Docs update (via `raftkit-dev:docs`, confirmed lifecycle) **only** when the
   documented contract was wrong, or the intended behavior changes within the
   bug's "Done when". Otherwise the fix carries the evidence-backed no-impact
   result. Behavior change beyond "Done when" routes to a new story — never
   smuggled into the fix.
7. **Commit and open the PR** per the shared git conventions (below).
8. **Close out.** Gate the claim with `superpowers:verification-before-completion` —
   observe the green run before asserting it — then close by path:
   - **Path A** — **fill "Fixed in build ___", mandatory.** Write the build / version
     into the bug task's "Done when" section. This is the retest contract; QA cannot
     retest without it, so the hand-back is **blocked** until it is filled. Hand back
     with the success line.
   - **Path B** — **offer the bug record.** Draft one from the four confirmed answers
     plus the build the fix landed in, shaped by the live Bugs Template, for draft →
     approve → file. **Declining is fine** — the PR and the permanent repro test are
     the record; a connector outage never blocks a finished fix.

   `references/bug-intake-and-handback.md`.

## Git conventions (same as feature work)

Bugs use the same loop as feature implementation — expressed as the shared
`raftkit-core` release-train conventions:

- one feature branch for the bug fix — named from the bug task on Path A, and from a
  short slug of the defect on Path B (no task, so no GID to name it from);
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
- **Never fix blind** — cannot-reproduce returns tried steps, the environment used, and
  one focused question; it is never guessed at.
- **The environment is always stated, never assumed** — the repro runs in the
  environment that was named, whether by the task's Environment block or by the dev at
  intake. The dev's local is a valid answer once said out loud; the failure this guards
  against is **silence**, not locality.
- **No ticket is never a blocker** — a dev who found the bug themselves runs Path B and
  is never turned away for lacking a task. This covers **no task at all**; a task that
  exists is linked and read, whatever the reason it was not pasted.
- **Path B is not a scope loophole** — it still requires a dev-stated "Done when",
  `scope-guard` audits the diff against it identically, and a refused ask **stops the
  run** just as a missing section bounces one on Path A. A feature or refactor wish is
  refused and routed, not folded into a "bug fix".
- **Bounce on a broken contract (Path A)** — a missing Environment, Steps to Reproduce,
  or "Done when" section goes back to QA before any fix, in the reference's exact
  wording and as a comment on the task, not just a chat line. QA filed it; QA completes
  it.
- **Scope = "Done when" only** — adjacent changes are `scope-guard` BEYOND flags,
  removed or signed off; the fix never expands past the "Done when" list.
- **Breaking another test is a hard stop** — fix-first; a fix that reddens the
  suite never ships.
- **Fixed-in-build is mandatory (Path A)** — the hand-back is blocked until the "Done
  when" section's `Fixed in build ___` is filled. Path B has no such field; it offers a
  declinable bug record instead.
- **Read live, never cache** — any bug task or Bugs Template this skill touches is
  fetched live at that moment; this repo holds zero template text. Path B's intake
  fetches nothing at all.
- **Escalate to founders** per `raftkit-core/house-rules` if a fix touches budget,
  contract, or client-commitment surface area.
- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.

## Out of scope

- **Filing bugs as QA's intake** — that is `raftkit-qa/file-bug`. Path B's offered
  record is a close-out of a fix already shipped, not a filing workflow.
- **Retesting a fix** — that is `raftkit-qa/retest`; this skill hands back, QA
  retests.
- **Production incidents** — that is the `fix-production-error` skill (a sibling in
  this same `raftkit-dev` plugin); this skill is for defects, not live incidents.
- **Features and refactors dressed as bugs** — a wish for new behaviour goes through a
  story and `implement`; a cleanup goes to the board as a proposal. No wrong behaviour,
  no red test, no run.

## Reference files

- `references/bug-intake-and-handback.md` — the path triage and the two refusals; Path
  A's live-template sections, its missing-sections bounce and `Fixed in build ___`; Path
  B's four asks, its refused-ask stop, and its declinable close-out record; the
  stated-environment rule; and the cannot-reproduce return. The bounce and the
  cannot-reproduce return both have **exact wording** there — use it, don't paraphrase.
- `references/fix-loop.md` — the red-before-fix mechanics, the permanent repro test,
  the `superpowers:systematic-debugging` → `scope-guard` → `simplify` orchestration seam, the
  git conventions, and the fix-breaks-another-test hard stop.
