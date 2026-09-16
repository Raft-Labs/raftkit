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

A task that exists but cannot be resolved stops the run; it never falls through to the reported path. A local, CI or test-run trace is an ordinary defect, not an incident.

## Run

1. **Get the contract**: environment, steps to reproduce, expected versus actual, and the `Done when` checklist that bounds the fix. Ticketed → read them from the task; a missing section bounces to QA as a drafted comment naming exactly what is absent:

```output
Can't start the fix — the bug task is missing <sections>. Add them before a repro test can be written and scoped. Back to QA.
```

   Reported → ask all four in one message and confirm the set back. A refused ask stops the run; the developer states the `Done when`, this skill never drafts it. Nothing is inferred: a guessed step is a fabricated contract.
2. **Reproduce, then make it red.** Replicate the defect in the stated environment (never a silent substitute), and encode it as a test that fails for the reason the bug describes. A test that passes, or fails for another reason, is not a repro. Cannot reproduce → report what was tried, the environment used, and one focused question; back to QA on the ticketed path, to the developer in session on the reported one. Never fix blind.
3. **Smallest fix to green.** Nothing speculative, nothing adjacent. The repro test is committed and stays in the suite forever. If the fix reddens any other test, stop and fix that first: never disable or delete a test to get green.
4. **Review once, in parallel** — the same pass `implement` runs (`implement/references/review.md`), with the `Done when` checklist in place of the acceptance criteria as the scope contract.
5. **Stop once** with the PR (`implement/references/pr.md`) and the hand-back: on the ticketed path the `Fixed in build` value and the hand-back comment; on the reported path an offered bug record drafted from the four confirmed answers, which the developer may decline.

```output
Red → green: repro test added, fix in PR #<n>, Fixed in build <x> — back to QA.
```

Declining the optional record is a first-class outcome: the repro test is permanent and the PR is the record.

## Incidents

Feature work halts until the incident is closed. Reproduce the crash as a failing regression test from the trace, fix, verify the whole suite, prepare the PR. Ask for the recent log stream before calling a deployment stable. A structural root cause becomes a drafted follow-up story, never a refactor under pressure. This skill never deploys: deployment is human and release-train owned.
