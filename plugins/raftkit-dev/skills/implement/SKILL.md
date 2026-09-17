---
name: implement
description: Take one Asana story from URL to a review-ready PR — "implement this story", "run /implement <story-url>", "build this task end to end", and on an existing branch "raise the PR", "check scope", "simplify this". Fetches the story once, shows the plan as it forms, builds test-first, reviews in one parallel pass, stops once. Never merges.
user-invocable: true
---

# implement

One story, one branch, one PR, one stop. `raftkit-core:rules` apply, and the repo's working agreement governs the build.

## Run

1. **Intake, in one turn**: the story and every `[AC]` subtask · the Feature Template if not already in this conversation · the Project Profile · `git fetch` of the target branch · the baseline build and typecheck. A red baseline stops here, with the failing command's output verbatim: fix it before touching feature code.
2. **Check readiness** inline against the fetched template (`raftkit-core:rules` → `references/readiness.md`). A gap the developer can answer is asked in the plan message, recorded in the plan record before the phases run, and drafted as a story comment at the stop. A gap that is commercial, client-facing, or that the developer will not answer ends the run with the gap list drafted as a story comment, for the PM to settle through `raftkit-pm:story` amend. That is the only early exit.
3. **Plan, in the open.** Branch by the release-train convention first, so the record lands on it. Scope is the `[AC]`s and nothing else. Phases are small enough to compile and test alone, each naming its files, its tier and its tests. Write the plan to `docs/specs/<branch>.md` and show it. It is a record, not a gate: the developer interrupts if it is wrong, and `--plan-only` stops here having written nothing but the record.
4. **Build.** Run the phases: independent phases in parallel, dependent ones in order, each as a subagent given only its files and the story text it needs. Every phase goes red first, one failing test per acceptance criterion, then green, through `superpowers:test-driven-development`; a failure that resists the quick fix switches to `superpowers:systematic-debugging`. Small conventional commits. A subagent that cannot fix the same error three times stops and reports.
5. **Review once, in parallel.** Re-fetch the story's `[AC]`s (a mid-run amend must not be missed), run the simplify pass, then fan out on the final diff: `pr-review-toolkit`'s code-reviewer, type-design-analyzer, silent-failure-hunter and pr-test-analyzer, plus `scope-guard`, `raftkit-dev:docs`, the security-guidance hook evidence, and lint with the full suite. Reviewers run on Sonnet unless a finding needs more. Fix or answer every finding; a scope flag blocks until it is removed or signed off. See `references/review.md`.
6. **Stop once** with everything that leaves the session: the PR title and its five sections, the Asana comment, the `Development` tick, and the run's token total. See `references/pr.md`.

```output
Story 1216… ready to raise: 14 files, 22 tests green, scope clean, docs not impacted.
PR title, description, and the Asana close-out are drafted above.
**STOP** — approve to push and raise, edit to change, or decline.
```

7. **On go**: push (never `--no-verify`; a hook rejection is surfaced verbatim and stops the raise), open the PR against the resolved squash target, then tick `Development` and comment the PR link. Report:

```output
PR #<n> raised — link on the story, Development ticked. Suite green: <x> tests. Scope: clean.
```

An Asana write that fails never rolls back the PR: report the story URL, the PR URL and the tick to do by hand.

## Standalone

On a branch that already has the work: "raise the PR" runs step 6 onward, "check scope" runs `scope-guard` alone, "simplify this" runs the simplify pass alone. Each reuses the story already in this conversation, or fetches it once when a fresh session does not hold it. Merging is always human, and this skill never ticks `[AC]` or `Testing` and never closes the story.
