# Bug intake and hand-back

This skill has **two intakes and one loop**. A bug filed by QA arrives as a templated
Asana task; a bug the developer found themselves arrives as their own report in the
session. Both must produce the same defect contract before a repro test is written —
what changes is where the contract comes from, never how strictly it is held.

## Which path — decide on entry

The branch is deterministic, and it turns on whether a bug task **exists** — not on
whether a link happened to be pasted:

- **A bug task exists** → **Path A · task-backed**. If it was referenced but not linked,
  resolve it — ask for the link, or search Asana if it was described well enough to find
  ("the bug QA filed yesterday on checkout"). A task that exists is read, never
  paraphrased from memory. If it cannot be resolved either way, **stop and say so**;
  an unresolvable task does not fall through to Path B.
- **No bug task exists** → **Path B · dev-reported**. Gather the contract in chat.

**Withholding a link never buys the conversational intake.** Path B's asks are not a
lighter version of Path A's sections — they are the same contract from a different
source, for a defect that has no source in Asana at all. A dev with an incomplete QA
ticket who omits the link would otherwise land in Path B and escape both the bounce
and the mandatory `Fixed in build ___`; that is the one substitution this skill
forbids. If a task exists, its close-out obligations apply in full.

Two entries are refused rather than routed to either path:

- **A production stack trace or log excerpt is pasted** (Sentry, CloudWatch,
  Crashlytics) → that is the incident loop. Route to the sibling
  `fix-production-error`; do not run an ordinary bug loop on live breakage. A
  **local, CI, or test-run** trace is not a production incident — it is an ordinary
  defect, and it takes the path its task status dictates.
- **A feature or refactor wish dressed as a bug** — "the API should also support X",
  "this module is ugly, clean it up" — is **not a defect**. There is no wrong
  behaviour to make red, so there is nothing for this skill to do. Refuse by name and
  route: a feature goes through a story and `implement`; a cleanup goes to the board
  as a proposal. Path B is an intake for defects the dev found, **not** a way around
  the board.

## Path A · task-backed

The live Bugs Template (GID from `raftkit-core/workflow-constants`) is this path's
**input contract**, and it is the contract **both ways** — the dev reads the same
sections QA is required to fill, and bounces the bug back the moment one the fix
depends on is absent. Read the template live every run; hold no template text in
this repo.

### The sections the fix depends on

Match on the section's **heading**, not its number — the template's numbering is
not stable. The three load-bearing sections:

- **Environment** — every field the live template's Environment block lists. This
  is the environment the repro test runs in.
- **Steps to Reproduce** — the deterministic steps the repro test replicates.
- **"Done when"** (the template's acceptance-criteria block) — the checklist that
  **defines the fix's scope**, plus the `Fixed in build / version ___` field the dev
  fills before hand-back.

### Hand-back 1 — missing contract sections (bounce before any fix)

The fix depends on three sections: Environment and Steps to Reproduce (the repro
contract) and "Done when" (the scope contract the diff is audited against). If any
is missing or empty, **do not attempt a fix.** Bounce the bug to QA using **this
wording**, naming the **exact** template sections that are missing so QA knows
precisely what to add. It goes on the task as a comment (draft → approve, per the write
rules below), not only into the dev's chat:

```
Can't start the fix — the bug task is missing <Environment | Steps to Reproduce |
"Done when" | the relevant combination>. The Bug Template needs <that section /
those sections> filled before a failing repro test can be written and its fix
scoped. Back to QA to complete it.
```

Name the section(s) by their template heading. The template is the contract both
ways: QA fills it, the dev holds them to it. This bounce is **Path A only** — if QA
filed the bug, QA completes it. Do not silently convert an incomplete task into a
Path B run by asking the dev to fill QA's gaps.

### Filling "Fixed in build ___" — mandatory before hand-back

Once the fix is green and the PR is open, write the build / version into the "Done
when" section's `Fixed in build / version ___` field on the bug task. This is the retest contract —
QA cannot retest a fix without knowing the build it landed in, so the hand-back is
**blocked** until this field is filled. Then hand back with the success line:

```
Red → green: repro test added, fix in PR #n, Fixed in build X — back to QA
```

## Path B · dev-reported

No task, no template, **no Asana read at intake**. The developer found the defect; the
contract comes from them. This path exists so a dev is never blocked on the absence of
a ticket — it is not a lighter bar. Every gate the loop applies still applies. (Asana
enters this path only at the close-out below, and only if the dev wants a record filed —
the template read that shapes the draft, then the approved write itself. Both happen
after the fix is already green.)

### The four asks — all four, confirmed, before any test

Ask for all four in **one** round, then confirm the set back before writing the repro
test. **Nothing here is inferred.** A guessed step or an assumed scope produces a
repro test for a defect that may not be the one the dev hit:

1. **Environment** — where it reproduces: the build or branch, the OS or browser, the
   URL or app target, and any data state the defect needs. The dev's own local machine
   is a perfectly valid answer — but it must be **said out loud**, not assumed by
   default (see below).
2. **Steps to Reproduce** — the steps, deterministic enough to encode directly as a
   test. If a step is vague ("then it breaks"), ask that one step down; if it still
   cannot be pinned, treat it as a refused ask and **stop** (below) — never guess the
   step. (This is an intake stop, not a cannot-reproduce hand-back; nothing has been
   attempted yet.)
3. **Expected vs Actual** — what should happen, and what happens instead. This is the
   **assertion the repro test makes**; without it there is no red to observe.
4. **"Done when"** — the checklist that defines the fix's scope, which `scope-guard`
   audits the diff against. **The dev states it; this skill does not draft it.** Scope
   is the dev's call, not an inference — and a dev-stated "Done when" is the only thing
   standing between this path and an unbounded diff. Call it "Done when" — the same name
   the scope contract carries on Path A — so the close-out draft and any later QA retest
   line up without translation. (No template read is needed for that; the name is this
   skill's own vocabulary.)

If the dev pushes back on stating a "Done when", the ask is small and concrete: what
must be true for this to count as fixed? One or two lines is enough. It is not
paperwork — it is the boundary the fix is held to.

**If any of the four is refused outright, the run stops.** Say which ask is unanswered
and why it is load-bearing — no steps or expected-vs-actual means no assertion to make
red; no "Done when" means no boundary for `scope-guard` to audit against, which is
exactly the unbounded diff this path must not produce. This is Path B's equivalent of
Path A's bounce, and it is not overridable by "just fix it".

### Path B close-out — the offered bug record

Once the fix is green and the PR is open, there is no `Fixed in build ___` field to
fill, because there is no task. Offer to create the record instead:

1. Fetch the **live** Bugs Template now (GID from `workflow-constants`) and shape the
   draft to it. This read happens only here, in service of an optional write, and only
   after the fix is green — never at intake. If the template or connector cannot be
   reached, say so plainly and ship on the PR alone; a connector outage never blocks a
   finished fix.
2. Draft the bug record from the **four confirmed answers** plus the build the fix
   landed in — no new information is needed, it was all gathered at intake.
3. Present it for `raftkit-core/write-protocol` draft → approve → file, and state
   plainly that declining is fine.

**Declining is a first-class outcome.** The repro test is committed and permanent
either way; the record exists so QA can retest and so the defect is traceable on the
board, not because the fix is incomplete without it.

The two Path B success lines — **filed**:

```
Red → green: repro test added, fix in PR #n, bug filed as <task> with Fixed in build X — QA can retest
```

and **declined**:

```
Red → green: repro test added, fix in PR #n. No bug task filed (declined) — the PR is the record, the repro test is the permanent guard.
```

## Environment — always stated, never assumed

The repro runs in the environment that was **stated**, on either path. On Path A that
is the Environment block: if it names Staging on a given build and OS, the repro
targets that — **never** the developer's local machine as a silent substitute. On Path
B it is whatever the dev named at intake, which may well be their local — valid, once
said.

The failure this guards against is **silence**, not locality. A fix "verified" in an
environment nobody named is the exact route to "still broken after the fix". If the
stated environment cannot be stood up, that is a cannot-reproduce hand-back (below),
not a quiet switch to local.

## Cannot reproduce — never fix blind

If the steps do not reproduce the defect in the stated environment, **do not fix
blind** on either path. The return carries exactly three things:

1. **What was tried** — the steps followed and the observations, streamed as they
   were attempted (the Waiting state: repro attempts are visible, not silent).
2. **The environment used** — the stated environment the attempt ran in, named
   explicitly so it can be lined up against the reporter's.
3. **One focused question** — exactly one, the single thing most likely to unblock
   reproduction (e.g. a missing precondition, an unclear step, a data-state detail).
   Not a list; one question.

```
Can't reproduce in the stated environment.
Tried: <steps followed + what was observed>
Environment used: <the environment stated at intake>
One question: <the single thing most likely to unblock repro>
```

Where it goes differs by path:

- **Path A** → the return goes **back to QA**; close the line with `Back to QA.` The
  run stops there.
- **Path B** → the question goes **to the dev, in session**. They are right here;
  resume the loop the moment they answer. The run only stops if they cannot answer.

## Asana write rules

Every write goes through `raftkit-core/write-protocol`: draft → approve → push. That
covers Path A's missing-sections bounce (posted as a comment on the bug task, so QA
sees it on the record — not only in the dev's chat), Path A's `Fixed in build` fill and
hand-back comment, and Path B's offered bug record. Apply the Asana HTML rules — single body root, no `<p>` (use line breaks),
attributes only on `<a href>`, escape `&`/`<`/`>`, and no named entities (write literal
characters). This skill never auto-writes; a human approves each write.
