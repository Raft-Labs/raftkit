---
name: pr-auto-review
description: This skill should be used when a developer or tech lead wants to install, update, or explain the automated PR review-and-fix workflow that runs in a CLIENT repo's CI — e.g. "add pr-auto-review to CI", "set up the PR review bot", "install pr-auto-review", or when setup-project's consolidated plan proposes it as an opt-in component. It ships a GitHub Actions workflow (pull_request opened/synchronize) that wraps anthropics/claude-code-action@v1 to invoke pr-review-toolkit:review-pr headlessly, auto-fixes and commits Critical findings one commit per fix (verify against the repo's strongest available check, auto-revert on red, disclose "unverified" when no check exists), and posts or edits one PR comment listing what was fixed and every Important/Suggestion finding by file:line. This skill is the sole named exception to raftkit-core's no-auto-commit rule — Critical-fix commits only, never a merge, fully attributed and revertible. Opt-in only — never installed silently by setup-project.
user-invocable: true
---

# pr-auto-review

Reviews every PR headlessly in CI, then auto-fixes what it safely can. It
installs a GitHub Actions workflow into a **client repo** (not this
repo) that wraps the official `anthropics/claude-code-action@v1` to invoke
`pr-review-toolkit:review-pr` on every `pull_request: opened` or
`synchronize` event, fixes and commits **Critical** findings one commit per
fix, and reports everything else in a single, edited-in-place PR comment.

## What this is, and is not

This skill's job **inside RaftKit** is to author and install the workflow
file — the same relationship `setup-project` has to `quality-guardrail.yml`.
It is not itself what runs in CI: once installed, the workflow invokes the
official `anthropics/claude-code-action@v1` directly with a fix-loop prompt
and `pr-review-toolkit` as an installed plugin. The client repo does not
need `raftkit-dev` installed at runtime for the workflow to run.

The name captures both halves of the job — it **reviews** the PR via
`pr-review-toolkit`, then **auto-fixes** what's safely fixable. It is not a
fix-only tool, and not a review-only tool like Anthropic's separate managed
"Code Review" service (`claude.ai/admin-settings/claude-code`) — that
service never commits or auto-fixes anything, so it does not substitute for
this skill; mention it as an alternative only when a developer explicitly
wants comments without any code changes.

## The one rule that governs everything

**Critical-fix commits are the one named exception to no-auto-commit.**
Everything else about RaftKit's write-protocol gate is unchanged: no
merges, no Asana writes, no direct pushes to protected branches, no edits
to `.github/workflows/**` (including its own file). See
`raftkit-core/write-protocol`'s "The two documented exceptions" (entry 2, pr-auto-review)
section and `raftkit-core/house-rules`' matching subsection for the exact,
binding boundary — this skill does not restate it, it inherits it.

## The limitation every installer must be told about

**The bot's commits are never exercised by the repo's own CI.** GitHub
suppresses workflow runs for events generated with the built-in
`GITHUB_TOKEN`, and that is what this workflow pushes with. So the repo's
test, lint and guardrail workflows do not run against the SHAs this bot
pushes, and a green check on the PR was computed on the commit *before* the
fixes.

Three things follow, and none of them are optional:

- The workflow's own in-job verification (`references/fix-loop.md`) is the
  only automated check those commits ever get.
- Every PR comment that reports a pushed commit states this in plain words,
  so the reviewer reads it in the artifact they are already reading.
- **A human must review the bot's commits before merging.** This is the
  same gate as the Gate 2 caveat below, for a second reason.

RaftKit takes the no-new-secrets path deliberately: no PAT, no GitHub App
private key added to a client repo. `references/install.md` documents the
App-token upgrade as an optional future path and the tradeoff it carries.

## Preconditions

- **`raftkit-core` installed** — the amendment above must exist in the
  target org's RaftKit install for this skill's exception to be valid.
- **`pr-review-toolkit` resolved** — already a declared `raftkit-dev`
  dependency (`plugin.json`), checked via `raftkit-dev:capability-preflight`.
  This skill invokes it exactly as `pr` and `scope-guard` do — it never
  re-implements finding classification.
- **The client repo has (or is getting) `setup-project`'s governance pack.**
  This workflow doesn't depend on the quality-guardrail workflow directly,
  but assumes the same repo conventions.
- **A manual precondition this skill cannot verify or provision:**
  `ANTHROPIC_API_KEY` must be added to the client repo's Actions secrets
  before the workflow can run (`Settings → Secrets and variables → Actions →
  New repository secret`). No RaftKit installer touches GitHub repo/org
  settings — this skill only prints the exact manual step; it can never
  confirm the secret exists (GitHub does not expose secret presence to
  `gh api` reads).

## Run flow

1. **Install** — as `setup-project`'s opt-in component 8 (see
   `references/install.md`): render `references/assets/pr-auto-review.yml`
   via `scripts/render-pr-auto-review.mjs`, write it to
   `.github/workflows/pr-auto-review.yml`, and print the manual secret step
   as a required next action.
2. **Update** — a re-run re-renders and diffs in place, same as any other
   pack-managed component, marker-owned so a re-run replaces it silently.
3. **What runs in the client repo's CI** — see `references/workflow-mechanics.md`
   for the trigger, the self-trigger loop guard, and diff anchoring; see
   `references/fix-loop.md` for the per-Critical-finding apply → verify →
   commit → revert loop and the three-tier verify resolution; see
   `references/comment-contract.md` for the exact PR comment shape and its
   edit-in-place marker.

## Guardrails

- **Critical-only auto-fix.** Important and Suggestion findings are reported
  in the PR comment, never auto-fixed.
- **pr-review-toolkit is the sole classifier.** If its slash command does not
  return a structured Critical/Important/Suggestion list, the run aborts and
  says so. An improvised, self-performed review is never a substitute.
- **One commit per fix**, never batched — a red result is attributable to
  exactly one fix.
- **A baseline verify run before the first fix.** Without it, a PR whose
  checks were already failing — the normal case for a PR under review — gets
  every correct fix discarded and a comment falsely blaming the fix. A red
  baseline drops the run to unverified-Tier-3 with its own distinct
  disclosure; it never attributes the failure to a fix.
- **Infrastructure failure is not a red fix.** A broken toolchain — install
  failed, harness could not start — aborts the run with a "cannot verify"
  disclosure and changes no code, rather than being read as "this fix broke
  the build".
- **Auto-revert-on-red**, naming the specific failing check, when a check
  exists and the baseline was green. When no check exists at all, the fix
  still commits but the comment carries a mandatory, permanent "unverified"
  disclosure — never silently implied to be equivalent to a verified fix.
- **Never merges.** The human always owns the PR-merge gate.
- **Never force-pushes and never rewrites remote history.** A push rejected
  because a human moved the branch stops the loop and is reported — never
  resolved with `pull --rebase` or `--force`.
- **Disclosure before commits, not after.** The summary comment is posted
  before the first fix and updated after each pushed commit, with an
  `if: always()` backstop, so a run that dies mid-loop can never leave bot
  commits on a branch with no disclosure.
- **Comment idempotency** — edited in place via a hidden marker found across
  *all* comment pages, never duplicated across re-runs.
- **Self-trigger loop guard** — the bot's own fix commits (identified by both
  a pinned commit author identity and the `pr-auto-review-commit` trailer,
  never by `github.actor`) are recognized and skipped, and a skip is always
  announced in the job summary rather than being silent.
- **Never runs on fork PRs or draft PRs** — both refused at job level, so no
  step can precede the check.
- **Never edits `.github/workflows/**`**, including its own file — a
  supply-chain-adjacent guardrail so the workflow can never alter its own
  trigger or permissions.
- **Escalate to founders** per `raftkit-core/house-rules` if an install of
  this skill implies a scope, contract, or client-relationship risk beyond
  the repo itself.
- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.

## Known interaction — `/implement`'s Gate 2 and `pr`

A known, unsolved limitation, documented so nobody is surprised by it. If a
repo runs both `/implement` and `pr-auto-review` over the same PR's lifecycle,
a Critical-fix commit pushed by CI **after** Gate 2 recorded its scope-guard
evidence invalidates that evidence: `implement/references/gates.md` requires
Gate 2 evidence to name the SHA it inspected and refuses a stale one, and
nothing re-triggers scope-guard when this workflow pushes. Separately, `pr`'s
finding-resolution gate expects every finding addressed before human review,
while this workflow resolves only Criticals out-of-band in CI — two
independent `review-pr` invocations with no arbitration between them. Until
that is designed, **a human must re-run Gate 2 after any pr-auto-review commit
before merging.**

## Out of scope

- **Secret provisioning** — printed as a manual step, never automated.
- **Auto-fixing Important or Suggestion findings** — report-only.
- **Filing to Asana** — the PR comment is the only surface; nothing here
  touches Asana.
- **Merging** — human-only, always.
- **Re-implementing `pr-review-toolkit`'s classification logic** — it is
  invoked, never re-bucketed.

## Reference files

- `references/install.md` — `setup-project` component-8 integration: the
  opt-in ask, the version-marker JSON addition, the manual-secret reminder.
- `references/workflow-mechanics.md` — trigger config, the self-trigger loop
  guard mechanism, diff anchoring, idempotent re-run behavior.
- `references/fix-loop.md` — the per-Critical apply → verify → commit →
  revert loop, the three-tier verify resolution, the hard boundaries stated
  in the fix-loop prompt.
- `references/comment-contract.md` — the marker string, edit-in-place
  mechanics via `gh api`, and the exact comment template.
