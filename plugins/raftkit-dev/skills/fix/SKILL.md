---
name: fix
description: Fix a defect the house way — "fix this bug <url>", "work this bug ticket", "I found a bug", "checkout is broken", or a pasted Sentry, CloudWatch or Crashlytics trace. The defect becomes a failing test before any fix, the diff stays inside the bug's Done when, and the run stops once. A feature request routes to implement.
user-invocable: true
---

# fix

One defect, one red test, one fix, one stop. `raftkit-core:rules` apply, and the repo's working agreement governs the build.

## Triage on entry

| What arrived | Path |
|---|---|
| A bug task in Asana (linked, or findable from a clear description) | **Ticketed.** Read it live; its sections are the contract. |
| A defect the developer found, no task | **Reported.** One batched ask gathers the same contract. |
| A production trace from Sentry, CloudWatch or Crashlytics | **Incident.** Halt feature work and say so, then the same loop with the extra rules below. |
| A feature or refactor wish ("it should also support X", "this module is ugly") | Not a defect. Name it and route: a feature to `implement` through a story, a cleanup to the board. |

One defect per run: a task or a report bundling unrelated defects stops and asks which one, never batches them. A task that exists but cannot be resolved stops the run; it never falls through to the reported path. A local, CI or test-run trace is an ordinary defect, not an incident.

## Run

1. **Get the contract**: environment, steps to reproduce, expected versus actual, and the `Done when` checklist that bounds the fix. Ticketed → read them from the task; a missing section bounces to QA as a drafted comment naming exactly what is absent:

```output
Can't start the fix — the bug task is missing <sections>. Add them before a repro test can be written and scoped. Back to QA.
```

   Reported → ask all four in one message and confirm the set back. A refused ask stops the run; the developer states the `Done when`, this skill never drafts it. Nothing is inferred: a guessed step is a fabricated contract.
2. **Reproduce, then make it red.** Replicate the defect in the stated environment (never a silent substitute) through `superpowers:systematic-debugging`, and encode it as a test that fails for the reason the bug describes. A test that passes, or fails for another reason, is not a repro. Cannot reproduce → stop with this, back to QA on the ticketed path and to the developer in session on the reported one. Never fix blind.

```output
Can't reproduce in the stated environment.
Tried: <steps followed and what was observed>
Environment used: <the environment stated at intake>
One question: <the single thing most likely to unblock repro>
```
3. **Smallest fix to green.** Nothing speculative, nothing adjacent. The repro test is committed and stays in the suite forever. If the fix reddens any other test, stop and fix that first: never disable or delete a test to get green.
4. **Review once, in parallel** — the same pass `implement` runs (`implement/references/review.md`), with the `Done when` checklist in place of the acceptance criteria as the scope contract.
5. **Stop once** with the PR (`implement/references/pr.md`, bug path) and the hand-back. On the ticketed path that is two Asana targets, both named in the draft: the hand-back comment, and the edit filling `Fixed in build ___` on the bug task with the build the fix landed in — the repo's own build or version number, the one QA will install. That field is the retest contract, so the approval of this stop is the explicit instruction the description edit needs. On the reported path it is an offered bug record drafted from the four confirmed answers, which the developer may decline.

```output
Red → green: repro test added, fix ready to raise, Fixed in build <x> — back to QA.
**STOP** — approve to push and raise, edit to change, or decline.
```

On go, raise the PR and write the approved Asana changes, then report:

```output
Red → green: repro test added, fix in PR #<n>, Fixed in build <x> — back to QA.
```

Declining the optional record is a first-class outcome: the repro test is permanent and the PR is the record.

## Incidents

A verbal description is not a trace: ask for the raw stack trace or log excerpt. A trace that does not localise asks for the missing artifact by name — a sourcemap, a request ID, a log window — and never guesses a line. One incident per run.

Feature work halts until the incident is closed. Reproduce the crash as a failing regression test from the trace, fix, verify the whole suite, prepare the PR. Ask for the recent log stream before calling a deployment stable. A structural root cause becomes a drafted follow-up story, never a refactor under pressure. This skill never deploys: deployment is human and release-train owned.
