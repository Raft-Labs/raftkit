---
name: implement
description: Take one Asana story from URL to a review-ready PR — "implement this story", "run /implement <story-url>", "build this task end to end", and on an existing branch "raise the PR", "check scope", "simplify this". Fetches the story once, shows the plan as it forms, builds test-first, reviews in one parallel pass, stops once. Never merges.
user-invocable: true
---

# implement

One story, one branch, one PR, one stop. Load `raftkit-core:rules` first unless it is already in this conversation. The repo's working agreement governs the build.

## Run

1. **Intake, in one turn**: the story and every `[AC]` subtask · the Feature Template · the Project Profile · the squash target and branch convention from the repo's own docs · `superpowers:test-driven-development` and the `pr-review-toolkit` agents available · `git fetch` of the target · the baseline build and typecheck. A miss stops here: an engine with `Missing: <engine>. Install it with: claude plugin install <engine>@claude-plugins-official`, a red baseline with the failing output verbatim, and no documented target with:

```output
no documented squash target — add the target branch and branch naming to CLAUDE.md, then re-run
```

   Several stories named → run the first and list the rest. After `/clear` or compaction, re-fetch the story once and resume from the phase status in the plan record.
2. **Check readiness** inline against the fetched template (`raftkit-core:rules` → `references/readiness.md`). A gap the developer answers in the plan message is recorded in the plan record before the phases run and drafted as a story comment at the stop. Any other gap — commercial, client-facing, or unanswered — ends the run with the gap list drafted as a story comment, for the PM to settle through `raftkit-pm:story` amend.
3. **Plan inline, in the open** — never through `superpowers:brainstorming`, `superpowers:writing-plans` or a `Plan` subagent. Branch by the documented convention first, so the record lands on it. Scope is the `[AC]`s and nothing else. Phases compile and test alone within working-agreement rule 2's file limit, each naming its files, its tier and its tests. Write the plan to `docs/specs/<branch>.md` and show it without waiting, with one line when this chat already holds another run. `--plan-only` stops here having written only the record; a run started in plan mode is `--plan-only` and writes nothing.
4. **Build.** Run the phases: independent phases in parallel, dependent ones in order, each a subagent at its tier's model (`references/review.md`), given only its files, the story text it needs and the branch SHA, which it confirms with `git merge-base --is-ancestor <sha> HEAD` before its first edit. Every phase goes red first, one failing test per acceptance criterion, then green, through `superpowers:test-driven-development`; a failure that resists the quick fix switches to `superpowers:systematic-debugging`. Small conventional commits; each green phase is marked done in the record.
5. **Review once, in parallel**: re-fetch the story's `[AC]`s, then run `references/review.md` with `references/simplify.md`.
6. **Stop once** with everything that leaves the session: the PR title and description, the Asana comment, the `Development` tick, and the run's token total. See `references/pr.md`.

```output
Story 1216… ready to raise: 14 files, 22 tests green, scope clean, docs not impacted, findings: 3 fixed / 1 answered.
PR title, description, and the Asana close-out are drafted above.
**STOP** — approve to push and raise, edit to change, or decline.
```

7. **On go**: push, open the PR against the squash target, then tick `Development` and comment the PR link. Report:

```output
PR #<n> raised — link on the story, Development ticked. Suite green: <x> tests. Scope: clean.
Next story: /clear first.
```

## Standalone

On a branch that already has the work: "raise the PR" runs step 6 onward, "check scope" runs `scope-guard` alone, "simplify this" runs the simplify pass alone. Each reuses the story already in this conversation, or fetches it once when a fresh session does not hold it.
