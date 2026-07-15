---
name: story-driver
description: Use this to build a RaftKit plugin skill end-to-end from an Asana story. Trigger whenever the user hands over a raftkit board task (a link or GID) and wants it implemented — e.g. "build this story", "implement this task", "do M3 · scope-guard", or pastes an app.asana.com task URL from the raftkit project. It fetches and parses the story into a scope contract, surveys what already exists, then orchestrates plugin-dev (scaffold + validate) and skill-creator (author + optimize) together to produce the skill, and finishes with a branch, commits, and a PR — pausing at the story, plan, and pre-push human gates. Use it even when the user only says "take this Asana task and develop it" without naming this skill.
user-invocable: true
---

# RaftKit Story Driver

Turn one approved Asana story into one merged-ready PR, the RaftLabs way:
**Spec-Driven + Test-Driven, human-in-the-loop at every gate.** The story is the
spec; its `[AC]` subtasks are the definition of done; nothing outside them enters
the diff. This skill orchestrates existing engines — it rebuilds none of them.

Run one story at a time. Work the steps in order; each gate is a hard stop that
waits for an explicit human "go" (silence is not approval).

## What this skill assumes

- `skill-creator` and `plugin-dev` are installed (the build engines).
- `raftkit-core` is installed — its `workflow-constants`, `house-rules`, and
  `write-protocol` skills carry the GIDs and the rules this skill obeys.
- The Asana connector is reachable.

If any is missing, stop and say which. For a missing constant or an unreachable
core, use the exact stop messages defined in `workflow-constants` — do not guess
a GID and do not fall back to a remembered template.

## Mode

Default to **dry-run** unless the user says to ship for real (e.g. "push it",
"open the PR", "for real"). In dry-run, every step runs except the outward writes
— no `git push`, no PR, no Asana write; drafts and exact commands are shown
instead. See `references/git-pr-flow.md`.

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
with no GID, **search the raftkit board for that name**, and if exactly one task
matches, confirm the match in one line and proceed; if zero or several match, ask
which. Never invent a target.

Then resolve the workspace + template GIDs from `workflow-constants` and fetch the
story **and all its subtasks** live via the Asana connector, plus the live User
Story Template as the format reference. Read templates live every run — never from
memory or from this repo.

### 2 · Understand + scope contract  → STORY-APPROVAL GATE
Parse the story per `references/story-parsing.md` and restate in chat:
- STORY title, surface, actor, permission boundary;
- the derived target `<plugin>/<skill>` (or "executable — CI/script/hook");
- the `[AC]` list verbatim — the **pass list**;
- the "Out of scope / non-goals" list verbatim — the **hard exclusion list**;
- any `❓`/unresolved facts or source conflicts — name them and ask; never guess.

**Stop for human approval of this scope contract before touching anything.**

### 3 · Survey the codebase
Report what already exists vs. what's to build: does the target plugin dir exist,
is it a bare stub, does the skill already exist, and which `raftkit-core` patterns
or sibling skills are reusable. Keep it factual — this is orientation, not a plan.

### 4 · Plan  → PLAN-APPROVAL GATE
Propose the approach and map **each `[AC]` → how it's satisfied → how it's
verified** (its "test"). For markdown skills the `[AC]`s are the tests; for
executable stories (CI/hooks/scripts) write a failing test first, then make it
pass (real TDD). State explicitly what stays out, echoing the exclusion list.

**Stop for human approval of the plan before building.**

### 5 · Build — engines together
See `references/engine-seam.md` for who owns what.
- Create the branch first: `feat/<milestone>-<skill-name>` (see git-pr-flow).
- **plugin-dev** scaffolds the plugin/skill files in-place (`plugin-structure` +
  `skill-development`; `create-plugin` only for a brand-new multi-part plugin).
- **skill-creator** authoring guidance drafts the SKILL.md content in the house
  style — third-person `description`, progressive disclosure, explain the *why*,
  no cached template text.
- QA: run the `plugin-validator` and `skill-reviewer` agents; fix what they flag.
- **Bump the touched `plugin.json` version** (semver: a new skill or feature is a
  minor bump, a fix/edit to an existing one is a patch) and keep the marketplace
  entry and manifest descriptions identical — the CI gate fails otherwise.

### 6 · Verify against the ACs
Walk every `[AC]` and confirm it is met. Confirm no out-of-scope item entered the
diff. Run the repo gate locally and require both green:
```
BASE_REF=main bash scripts/validate.sh
bash tests/validate.test.sh
```

### 7 · Close the loop + ship  → PRE-PUSH GATE
Per `references/git-pr-flow.md` and `write-protocol`: draft the conventional-commit
PR title (a changelog line) + body (links the story, lists the ACs), and the Asana
`Development`-tick + PR-link comment.

**Show the diff summary + PR body + Asana draft in chat and wait for explicit
approval.** Then — and only when not in dry-run — push the branch, open the PR,
and write the Asana updates. Report the PR URL and the task link.

Do not merge the PR, tick `[AC]`/`Testing`, or close the story — those are
downstream human/QA gates.

## Scope is a hard line

Anything not in the `[AC]`s is out. Improvements you spot go to the board as
proposals (a new task or a comment on the story), never into this diff. If the
work touches budget, contracts, relationship risk, or a client commitment,
escalate to founders per `house-rules` — do not decide it here.
