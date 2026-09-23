---
name: story-driver
description: Builds a RaftKit change from one story on the raftkit Asana board — "build this story", "implement this task", "do M3 · scope-guard", "take this Asana task and develop it", or a pasted task link or GID. Parses the story into a scope contract, builds test-first, runs every repo suite, and stops once before any push, PR or Asana write.
user-invocable: true
---

# RaftKit Story Driver

Turn one approved Asana story into one merge-ready PR, the RaftLabs way: the
story is the spec, its `[AC]` subtasks are the definition of done, and nothing
outside them enters the diff. This skill orchestrates existing engines — it
rebuilds none of them.

Run one story at a time, in order. The scope contract and the plan are shown as
they form, not gated; the run stops exactly once, before the push and the Asana
writes (`raftkit-core:rules`).

## What this skill assumes

- `raftkit-core` is installed — its `rules` skill carries the GIDs and the rules
  this skill obeys.
- `plugin-dev` is installed — its reviewer agents check every build.
- `skill-creator` is installed when the story scaffolds a new plugin or skill.
- The Asana connector is reachable.

If any is missing, stop and say which. For a missing constant or an unreachable
core, use the exact stop messages in `raftkit-core:rules` — never guess a GID and
never fall back to a remembered template.

## Mode

A run is real unless the user says **dry-run** or **practice**. In dry-run, every
step runs except the outward writes — no `git push`, no PR, no Asana write;
drafts and exact commands are shown instead. See `references/git-pr-flow.md`.

## The flow

### 0 · Preconditions
Confirm the assumptions above. Confirm the working tree is clean before
branching; if there are uncommitted changes, stop and ask. Branch off the latest
`main` in the normal case — but if you are already in an isolated worktree or on
a purpose-made branch (a re-run, a sandbox), branch from the current HEAD and say
so rather than treating "not on main" as a hard stop.

### 1 · Fetch the story
Get the story identifier. If the user pasted a task **link or GID**, use it. If
they named the board task instead (e.g. "M3 · scope-guard", "do story-readiness")
with no GID, **search the development board named in `CLAUDE.md` for that
name**, and if exactly one task matches, confirm the match in one line and
proceed; if zero or several match, ask which. Never invent a target.

Then resolve the workspace GID and the **Feature Template** constant from
`raftkit-core:rules` and fetch the story **and all its subtasks** live via the
Asana connector, plus the live Feature Template as the format reference. Read
templates live every run — never from memory or from this repo.

### 2 · Understand + scope contract
Parse the story per `references/story-parsing.md` and restate in chat:
- STORY title, surface, actor, permission boundary;
- the derived target `<plugin>/<skill>` (or "executable — CI/script/hook");
- the `[AC]` list verbatim — the **pass list**;
- the `Do NOT build:` line under `3 · Scope` verbatim — the **hard exclusion
  list**;
- any `[Unresolved]` item or source conflict — name it and ask; never guess.

Show the contract and carry on. An unresolved item or a source conflict is a
question in the same message, and the run does not build past it until it is
answered.

### 3 · Survey the codebase
Report what already exists vs. what's to build: does the target plugin dir exist,
is it a bare stub, does the skill already exist, and which `raftkit-core` patterns
or sibling skills are reusable. Keep it factual — this is orientation, not a plan.

### 4 · Plan
Propose the approach and map **each `[AC]` → how it's satisfied → how it's
verified** (its "test"). For markdown skills the `[AC]`s are the tests; for
executable stories (CI/hooks/scripts) write a failing test first, then make it
pass (real TDD). State explicitly what stays out, echoing the exclusion list.

Show the plan and start building. It is a record, not a gate: interrupt if it is
wrong.

### 5 · Build
See `references/engine-seam.md` for who owns what.
- Create the branch first: `feat/<skill-name>` (see git-pr-flow).
- **New plugin or skill only:** **plugin-dev** scaffolds the files in-place
  (`plugin-structure` + `skill-development`; `create-plugin` only for a
  brand-new multi-part plugin), and **skill-creator** authoring guidance drafts
  the SKILL.md content in the house style — third-person `description`,
  progressive disclosure, explain the *why*, no cached template text.
- **Edit to an existing skill:** edit in place within its `tests/budgets.json`
  entry; load neither plugin-dev's skills nor skill-creator.
- QA, in parallel: dispatch `plugin-dev:plugin-validator` with
  `model: "haiku"` when a plugin changed and `plugin-dev:skill-reviewer` with
  `model: "sonnet"` when a SKILL.md changed; fix what they flag.
- **Bump the touched `plugin.json` version** (semver: a new skill or feature is a
  minor bump, a fix/edit to an existing one is a patch) and keep the marketplace
  entry and manifest descriptions identical — the CI gate fails otherwise.

### 6 · Verify against the ACs
Walk every `[AC]` and confirm it is met. Confirm no out-of-scope item entered the
diff. Run the repo gate and every contract suite locally:
```
BASE_REF=main bash scripts/validate.sh
for t in tests/*.test.sh; do out=$(bash "$t" 2>&1) || printf 'SUITE FAILED: %s\n%s\n' "$t" "$out"; done
```
`validate.sh` must end on `OK:` and the loop must print nothing. A red suite is
fixed before the stop, never shown at it.

### 7 · Close the loop + ship  → the one stop
Per `references/git-pr-flow.md` and `raftkit-core:rules`: draft the
conventional-commit PR title (a changelog line) and body (links the story, lists
the acceptance criteria), plus the Asana `Development` tick and PR-link comment.

Show the diff summary, the PR body and the Asana draft together, ending with the
`**STOP**` line. On an explicit go — and only when not in dry-run — push the
branch, open the PR and write the Asana updates. Report the PR URL and the task
link.

Never merge the PR, tick `[AC]` or `Testing`, or close the story.

## Scope is a hard line

Anything not in the `[AC]`s is out. Improvements you spot go to the board as
proposals (a new task or a comment on the story), never into this diff. If the
work touches budget, contracts, relationship risk, or a client commitment,
escalate to founders per `raftkit-core:rules` — do not decide it here.
