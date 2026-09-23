---
name: implement
description: Take one Asana story from URL to a review-ready PR — "implement this story", "run /implement <story-url>", "build this task end to end", and on an existing branch "raise the PR", "check scope", "simplify this". Fetches the story once, shows the plan as it forms, builds test-first, reviews in one parallel pass, stops once. Never merges.
user-invocable: true
---

# implement

One story, one branch, one PR, one stop. Load `raftkit-core:rules` first unless it is already in this conversation. The repo's working agreement governs the build.

## Run

In plan mode: read only (no fetch, build or verify), show the plan and end.

1. **Intake, in one turn**: the story and every `[AC]` subtask; the Feature Template; the Project Profile; the squash target and branch convention from the repo's own docs; `superpowers:test-driven-development` and the `pr-review-toolkit` agents available; `git fetch` of the target; the baseline build and `node ${CLAUDE_PLUGIN_ROOT}/scripts/verify.mjs --only typecheck`. A miss stops here: an engine with `Missing: <engine>. Install it with: claude plugin install <engine>@claude-plugins-official`, a red baseline with the failing output verbatim, and no documented target with:

```output
no documented squash target — add the target branch and branch naming to CLAUDE.md, then re-run
```

   Several stories named → run the first and list the rest. After `/clear` or compaction, re-fetch the story once and resume from the phase status in the plan record.
2. **Check readiness** inline against the fetched template (`raftkit-core:rules` → `references/readiness.md`). A gap the developer answers in the plan message is recorded in the plan record before the phases run and drafted as a story comment at the stop. Any other gap (commercial, client-facing, or unanswered) ends the run with the gap list drafted as a story comment.
3. **Plan inline, in the open**, never through `superpowers:brainstorming`, `superpowers:writing-plans` or a `Plan` subagent. Branch first, by the documented convention. Phases keep to working-agreement rule 2's file limit, each naming its files, tier and tests. Write the plan to `docs/specs/<branch>.md` and show it without waiting, with one line when this chat already holds another run. `--plan-only` stops here having written only the record.
4. **Build.** Independent phases run in parallel, dependent ones in order, each a subagent at its tier's model (`references/review.md`) with `isolation: "worktree"`, given only its files, the story text it needs and the branch SHA, which it confirms with `git merge-base --is-ancestor <sha> HEAD` before its first edit; a failed check means no setup: run the phases in order without isolation. Every phase goes red first, one failing test per acceptance criterion, then green, through `superpowers:test-driven-development`; a failure that resists the quick fix switches to `superpowers:systematic-debugging`. Each phase makes one conventional commit, tests and code together, which the parent cherry-picks onto the branch in plan order; only the parent marks phases done in the record, and commits it with the last phase.
5. **Review once, in parallel**: re-fetch the story's `[AC]`s, then run `references/review.md` with `references/simplify.md`.
6. **Stop once** with everything that leaves the session: the PR title and description, the Asana comment, the `Development` tick, and the line `node ${CLAUDE_PLUGIN_ROOT}/scripts/run-tokens.mjs ${CLAUDE_SESSION_ID}` prints, quoted as printed (`Token total: not measured` if it cannot run). See `references/pr.md`.

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

On a branch that already has the work: "raise the PR" runs step 6 onward, "check scope" runs `scope-guard` alone, "simplify this" runs the simplify pass alone. Each resolves the squash target as step 1 does.
