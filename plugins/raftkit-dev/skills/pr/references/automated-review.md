# Automated review — before a human is asked

After the PR is open, the automated layers run and are cleared **before** a human
reviewer is requested. Humans review judgment, not checklists — so the machines go
first (PRD §2 #18: hundred-file AI diffs can't be audited by humans alone).

## The layers

- **pr-review-toolkit — the declared dependency, always.** Invoke its verified
  entry component `pr-review-toolkit:review-pr` on the raised PR; its reviewer
  agents are dispatched by their scoped names from the verified inventory.
  Readiness is `raftkit-dev:capability-preflight`'s call — "always" holds
  because the plugin is a declared dependency of raftkit-dev; if preflight
  reports it unresolved, stop with the repair guidance (a human-approved
  RaftKit install/update) rather than skipping the layer or improvising an
  install.
- **CodeRabbit — when present.** Wrap the CodeRabbit PR app when it is
  licensed/installed for the repo. When it is **not** present, skip it with an
  explicit note in the run output (e.g. "CodeRabbit not installed — skipped");
  never block on a layer the repo does not have, and never silently drop it.
  (CodeRabbit licensing is an open decision, Asana `1216551482947559` — treat it as
  a parameter, not an assumption.)

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
