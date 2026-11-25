---
name: implement
description: Take one Asana story from URL to a review-ready PR — "implement this story", "run /implement <story-url>", and on an existing branch "raise the PR", "check scope", "simplify this". Test-first per acceptance criterion, one review, one stop. Never merges.
user-invocable: true
---

# implement

One story, one branch, one PR, one stop. Load `raftkit-core:rules` first unless it is already in this conversation.

- **One stop**, before the push, the PR and the Asana writes. Never merge; never tick `[AC]` or `Testing`.
- **Scope**: the `[AC]`s are the contract. Nothing on the story's `Do NOT build:` line, nothing outside the plan table.
- **Red first**: each `[AC]`'s failing test is committed before its code.

## Run

In plan mode: read only (no `git fetch`, branch, build or verify), show the plan and end.

1. **Intake, in one turn**: the story, every `[AC]` verbatim and its `Do NOT build:` line; the live Feature Template; the Project Profile's stack, environments and conventions sections; the squash target and branch convention from the repo's docs; the installed engines; one `git fetch` of the target, pinning `<base-sha>` to `git merge-base FETCH_HEAD HEAD`; in the background, `node ${CLAUDE_PLUGIN_ROOT}/scripts/verify.mjs --only typecheck`, plus the build where it is a separate compile. A missing engine stops with `Missing: <engine>. Install it with: claude plugin install <engine>@claude-plugins-official`; a red baseline with its output verbatim (`no typecheck script` is not red); no documented target with:

```output
no documented squash target — add the target branch and branch naming to CLAUDE.md, then re-run
```

   Several stories named → run the first, list the rest. After `/clear` or compaction, re-fetch the story and resume from the plan record and the git log.
2. **Check readiness**: all six gap types against the live template (`raftkit-core:rules` → `references/readiness.md`), unless a readiness `PASS` comment is newer than the story's last edit. A gap the developer answers goes into the plan record and the stop's story comment; any other gap ends the run, drafted as a story comment.
3. **Plan in the main thread**, never through a planning skill or a `Plan` subagent. Explore once. More than 25 files planned stops here:

```output
Can't build this in one run — <n> files planned, over 25. Split the story through raftkit-pm:story, then re-run.
```

   Otherwise branch by the convention. Write the plan to `docs/specs/<branch>.md` by `references/plan.md`, hash the table with `node ${CLAUDE_PLUGIN_ROOT}/scripts/scope-check.mjs --hash`, commit the record alone and show it without waiting. `--plan-only` stops here.
4. **Build in the main thread, one `[AC]` at a time**, by the method below; by `references/pair.md` only when the plan marks FE and BE independent.
5. **Review once** by `references/review.md`, with `node ${CLAUDE_PLUGIN_ROOT}/scripts/scope-check.mjs --base <base-sha>`, `node ${CLAUDE_PLUGIN_ROOT}/scripts/verify.mjs` and `node ${CLAUDE_PLUGIN_ROOT}/skills/docs/scripts/validate-docs.mjs --root . --base <base-sha>`.
6. **Stop once** with the PR title and description (`references/pr.md`), the Asana comment, the `Development` tick, and the line `node ${CLAUDE_PLUGIN_ROOT}/scripts/run-tokens.mjs ${CLAUDE_SESSION_ID} --stages` prints, quoted as printed (`Token total: not measured` if it cannot run).

```output
Story 1216… ready to raise: 14 files, 22 tests green, scope clean, docs not impacted, findings: 3 fixed / 1 answered.
PR title, description, and the Asana close-out are drafted above.
**STOP** — approve to push and raise, edit to change, or decline.
```

7. **On go**: push, open the PR, tick `Development`, comment the PR link. Report:

```output
PR #<n> raised — link on the story, Development ticked. Suite green: <x> tests. Scope: clean.
Next story: /clear first.
```

## Method, per `[AC]`

1. Write one test asserting the `[AC]` as written, through the public interface.
2. Run it. It must fail for the reason the `[AC]` names; a compile error or another failure is not red. Commit it alone: `test: <the [AC]>`.
3. Write the least code that turns it green. Run the targeted tests and the package typecheck, refactor only while green, and commit.

A stubborn failure: reproduce it with one command, write one hypothesis, change one variable, rerun. Three strikes on the same error stops the run and reports.

## Standalone

On a branch that already has the work: "raise the PR" runs step 6 onward, "check scope" runs `scope-guard`, "simplify this" runs `references/review.md` step 1. Each resolves the squash target as step 1 does.
