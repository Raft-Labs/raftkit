# Incident loop — trace → red → green → prepare

The mechanical loop once the front gates (`references/triage-and-refusal.md`) have
passed and a real, localizable production trace is in hand. It executes Protocol 5
— read live from `raftkit-core/governance-protocols` every run, never cached.

## 1 · Halt feature work

A pasted production trace suspends the session's feature work. Say so explicitly —
the developer needs to know the session has switched to incident mode. Nothing
else in the backlog proceeds until this incident is resolved or handed off. One
incident per run; if a second trace arrives mid-run, finish or hand off the first
before starting it. Severity is **S1 until triage** says otherwise.

## 2 · Trace the exact failing line

Wrap `superpowers/systematic-debugging` — do not reimplement diagnosis. Drive it
to the precise line raising the runtime exception or unhandled promise rejection,
following the trace through the frames it points at. If the frames do not localize
(minified stack, missing request context), stop and return to the ambiguous-trace
gate in `references/triage-and-refusal.md` — ask for the named artifact, never
guess a line.

## 3 · Write the failing regression test — first, and permanent

Before writing any fix, encode the **exact crash conditions** from the trace as a
regression test, run it, and **confirm it fails red**. This is red-first TDD under
incident pressure: the test proves the crash is captured, and it stays in the
suite permanently so the same crash can never regress silently.

**Cannot replicate the crash in a test** — say **exactly what is missing** (the
input, the state, the environment the trace implies but you cannot reconstruct)
and ask for it. Never fabricate a fix against a crash you could not first turn
red; an unreplicated crash is not understood.

## 4 · Fix to green — containment, not refactor

Implement the **smallest** change that turns the red regression test green. The
fix scope is **the crash only** — any change beyond it is a scope-guard violation
(see below).

If the root cause is **systemic** (the fix would mean an architecture change, not
a line fix), do **not** refactor under incident pressure. Ship the **containment
fix + the regression test** that stops the bleeding, and draft a **follow-up task
proposal** for the structural work per `references/triage-and-refusal.md`.

## 5 · Verify the full suite — hard stop on breakage

Run the **whole** suite, not just the new test. The regression test must be green
**and** every previously passing test must stay green. A fix that turns any other
test red is a **hard stop**: the incident is not resolved while the suite is red.
Fix the regression first; do not proceed, do not prepare a PR, and never suggest
deploy on a red suite.

## 6 · Scope hand-off

Fix scope is the crash. Before the PR, the diff goes to `raftkit-dev/scope-guard`
— anything beyond the crash lands in its BEYOND list for a human call.
Behaviour-preserving cleanup, if wanted, is `raftkit-dev/simplify`, run
separately. This skill adds neither; it stays on the incident.

## 7 · Prepare — never deploy

Prepare the branch and PR (regression test + containment fix) **via the
`raftkit-dev/pr` sibling when present, falling back to the shared PR conventions
when it is absent**, and **suggest** the deploy steps only. Deploy stays human and
release-train governed — the skill has no deploy action. Close with the exact
success line, verbatim:

```
Crash replicated red → fixed green. Regression test permanent. PR #n ready — deploy per the train.
```

Replace `#n` with the real PR number once the PR exists; the rest is fixed wording.
