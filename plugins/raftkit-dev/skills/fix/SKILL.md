---
name: fix
description: Fix a defect — "fix this bug <url>", "work this bug ticket", "I found a bug", "checkout is broken", or a pasted Sentry, CloudWatch or Crashlytics trace. The defect becomes a failing test before any fix, the diff stays inside the bug's Done when, and the run stops once. A feature request routes to implement.
user-invocable: true
---

# fix

Load `raftkit-core:rules` first unless it is already in this conversation.

- **One stop**, before the push, the PR and the Asana writes. Never merge; never close the bug.
- **Scope**: the bug's `Done when` is the contract. Nothing adjacent, nothing speculative.

## Triage on entry

| What arrived | Path |
|---|---|
| A bug task in Asana (linked, or findable from a clear description) | **Ticketed.** Read it live; its sections are the contract. |
| A defect the developer found, no task | **Reported.** One batched ask gathers the same contract. |
| A production trace from Sentry, CloudWatch or Crashlytics | **Incident.** Halt feature work and say so; see Incidents. |
| A feature or refactor wish | Not a defect: route a feature to `implement` through a story, a cleanup to the board. |

One defect per run: a bundle of unrelated defects stops and asks which one. An existing task binds in full, linked or not; an unresolvable one stops the run, never falling through to the reported path. A local, CI or test-run trace is an ordinary defect, not an incident. A chat already holding another run says so in the first reply.

## Run

Before the first reply, read the squash target and branch convention from the repo's own docs; none stops the run with `no documented squash target — add the target branch and branch naming to CLAUDE.md, then re-run`.

1. **Get the contract**: environment, steps to reproduce, expected versus actual, and the `Done when` checklist that bounds the fix. Ticketed → read them from the task; a missing section bounces to QA as a drafted comment naming exactly what is absent:

```output
Can't start the fix — the bug task is missing <sections>. Add them before a repro test can be written and scoped. Back to QA.
```

   Reported → ask all four in one message; echo the answers atop the next reply. A refused ask stops the run; the developer states the `Done when`, never this skill.

   Then one `git fetch` of the target, pinning `<base-sha>` to `git merge-base FETCH_HEAD HEAD`, and a branch by that convention. Start the baseline in the background (`node ${CLAUDE_PLUGIN_ROOT}/scripts/verify.mjs --only typecheck`, plus any separate build); collected before step 2, red stops the run with its output verbatim. Write `docs/specs/<branch>.md` by `plan.md` in `${CLAUDE_PLUGIN_ROOT}/skills/implement/references/`, one row per `Done when` item, hash it with `node ${CLAUDE_PLUGIN_ROOT}/scripts/scope-check.mjs --hash` and commit it alone. Steps 2 and 3 run in this thread, by the debugging method below.
2. **Reproduce, then make it red.** Replicate the defect in the stated environment (never a silent substitute), and encode it as a test that fails for the reason the bug describes. A test that passes, or fails for another reason, is not a repro. Cannot reproduce → stop with this, back to QA (ticketed) or the developer (reported). Never fix blind.

```output
Can't reproduce in the stated environment.
Tried: <steps followed and what was observed>
Environment used: <the environment stated at intake>
One question: <the single thing most likely to unblock repro>
```
3. **Smallest fix to green.** The repro test is committed alone and stays in the suite forever; the fix is a separate `fix:` commit. After both commits the whole suite runs through `node ${CLAUDE_PLUGIN_ROOT}/scripts/verify.mjs --only test`, which the gate batch reuses; if the fix reddens any other test, stop and fix that first: never disable or delete a test to get green.
4. **Review once** by `${CLAUDE_PLUGIN_ROOT}/skills/implement/references/review.md`, the `Done when` items in place of the `[AC]`s. Its gate batch runs `node ${CLAUDE_PLUGIN_ROOT}/scripts/verify.mjs`, `node ${CLAUDE_PLUGIN_ROOT}/scripts/scope-check.mjs --base <base-sha>` and `node ${CLAUDE_PLUGIN_ROOT}/skills/docs/scripts/validate-docs.mjs --root . --base <base-sha>`.
5. **Stop once** with the PR (implement's `pr.md`, bug path), the hand-back, and what `node ${CLAUDE_PLUGIN_ROOT}/scripts/run-tokens.mjs ${CLAUDE_SESSION_ID} --stages` prints, verbatim (`Token total: not measured` if it cannot run). On the ticketed path that is two Asana targets, both named in the draft: the hand-back comment, and the edit writing `Fixed in build: pending — first build containing PR #<n>` on the bug task. Approving this stop is the explicit instruction that edit needs. On the reported path it is an offered bug record drafted from the four answers, which the developer may decline.

```output
Red → green: repro test added, fix ready to raise, Fixed in build: pending — back to QA.
**STOP** — approve to push and raise, edit to change, or decline.
```

On go, raise the PR and write the approved Asana changes, then report:

```output
Red → green: repro test added, fix in PR #<n>, Fixed in build: pending — first build containing PR #<n>. Back to QA.
Next story: /clear first.
```

Declining the bug record leaves the repro test and the PR standing.

## Debugging method

1. Reproduce: one command that shows the failure every time.
2. Write down one hypothesis naming the cause.
3. Change one variable to test it, then rerun the repro.
4. Wrong: revert that change and form the next hypothesis. Three strikes on the same error stops and reports; the developer decides.

## Incidents

A verbal description is not a trace: ask for the raw stack trace or log excerpt. A trace that does not localise asks for the missing artifact by name (sourcemap, request ID, log window); never guess a line.

Ask for the recent log stream before calling a deployment stable. A structural root cause becomes a drafted follow-up story, never a refactor under pressure. Never deploy.
