# Automated review — before a human is asked

After the PR is open, the automated layers run and are cleared **before** a human
reviewer is requested. Humans review judgment, not checklists — so the machines go
first (PRD §2 #18: hundred-file AI diffs can't be audited by humans alone).

## Scope — an explicit range, never the tool's default

`pr-review-toolkit:review-pr` and its agents default to unstaged `git diff`
(`code-reviewer.md`: "By default, review unstaged changes from `git diff`") —
**empty** by the time a PR is raised and pushed, since the working tree is
clean at that point. Never invoke the toolkit on its default scope here;
anchor it explicitly, the same way `scope-guard` anchors
(`scope-guard/references/audit-method.md`, "Anchoring the diff"):

```
git fetch origin <squash-target>
git diff "$(git merge-base FETCH_HEAD HEAD)" HEAD
```

Pass this range (or the equivalent PR diff) to the toolkit explicitly. A run
that reports "clean" without having named a non-empty range it reviewed has
reviewed nothing — treat that as a failure to invoke, not a passing result.

## The layers

- **pr-review-toolkit — the declared dependency, always.** Invoke its verified
  entry component `pr-review-toolkit:review-pr` on the merge-base range above,
  with **explicit aspects** rather than the tool's own routing: `comments tests
  errors types code`. **`types` is unconditional** — `type-design-analyzer` is
  the only design-aware reviewer in the toolkit's inventory, and the tool's own
  default only runs it "if types added/modified" (`review-pr` command); RaftKit
  always wants that lens dispatched, so it is named explicitly rather than left
  to the tool's conditional routing. **`simplify` is deliberately excluded**
  from this aspect list — `raftkit-dev/simplify` already ran the guarded pass
  earlier in this run (diff-only, approval-gated, auto-revert-on-red;
  `simplify/references/revert-safety.md`), and the toolkit's own `simplify`
  aspect dispatches its `code-simplifier` agent **unguarded**, with none of
  that safety net. Its reviewer agents are dispatched by their scoped names
  from the verified inventory. Readiness is `raftkit-dev:capability-preflight`'s
  call — "always" holds because the plugin is a declared dependency of
  raftkit-dev; if preflight reports it unresolved, stop with the repair
  guidance (a human-approved RaftKit install/update) rather than skipping the
  layer or improvising an install.
- **CodeRabbit — not part of the review chain.** RaftLabs decided to use
  pr-review-toolkit only (Asana `1216551482947559`, closed 2026-07-14). Do not
  invoke CodeRabbit here, and do not report its absence as a skipped layer —
  there is no layer to skip. Revisit only if that decision changes.

## The gate — address or explicitly answer, then request review

Every finding from the layers that ran must be either:

- **Addressed** — fixed with a follow-up commit on the branch, or
- **Explicitly answered** — a logged reply on the finding saying why no change is
  needed.

Silence is not resolution. Only once every finding is addressed or answered is the
human reviewer requested, with the fixed success line:

```
automated layers clean — requesting human review
```

If findings remain open, do not request the human reviewer yet — report what is
outstanding.

## The hard guardrail — never merge, never self-approve

`pr` raises the PR and requests review. It does **not** merge, promote, tag, or
approve its own PR — those are human-only and release-train-owned, even when every
automated layer is green. A clean PR is handed to a human; it is never self-merged.
