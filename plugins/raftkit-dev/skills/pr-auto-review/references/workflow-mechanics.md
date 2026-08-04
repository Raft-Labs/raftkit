# Workflow mechanics — trigger, loop guard, diff anchoring, idempotent re-run

## Trigger

`pull_request: [opened, synchronize]` — re-reviews on every push to the PR,
not just once at open. No `reopened`/`edited` (unlike RaftKit's own
`validate.yml`, which validates a different thing) — this workflow's scope
is strictly "re-review on every new push."

`concurrency` is keyed on the PR number, `cancel-in-progress: true`, so a
rapid double-push doesn't run two fix loops against the same PR
simultaneously and race each other's commits:

```yaml
concurrency:
  group: pr-auto-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true
```

## The self-trigger loop guard

Every fix commit this workflow makes carries a `pr-auto-review-commit: true`
trailer in its commit message body (see `fix-loop.md`). Before invoking the
official action, a guard step checks the last commit's author identity:

```yaml
- uses: actions/checkout@v4
  with:
    ref: ${{ github.event.pull_request.head.ref }}
    fetch-depth: 0
- name: Check last commit is not our own fix
  id: guard
  run: |
    AUTHOR_EMAIL="$(git log -1 --pretty=format:'%ae')"
    if [ "$AUTHOR_EMAIL" = "__BOT_COMMIT_EMAIL__" ]; then
      echo "skip=true" >> "$GITHUB_OUTPUT"
    else
      echo "skip=false" >> "$GITHUB_OUTPUT"
    fi
```

Every subsequent step (including the `anthropics/claude-code-action@v1`
invocation) is gated `if: steps.guard.outputs.skip != 'true'`.

**Why the commit author identity, not `github.actor`:** `github.actor`
reflects the push event's actor, which — depending on whether a GitHub App
token or a PAT was used to push the fix commit — can read ambiguously. The
commit author identity is fully controlled by this workflow itself (set via
`git config user.email` before committing, see `fix-loop.md`), so it's the
one signal that's reliable regardless of token/App identity used for the
push.

`__BOT_COMMIT_EMAIL__` is a rendered token (see `install.md`), a fixed,
documented value chosen once at install time — never invented per run.

## Diff anchoring

Fetch the PR's base ref, then diff from the merge-base — the same pattern
`scope-guard/references/audit-method.md` uses for its own diff analysis:

```bash
git fetch origin "${{ github.event.pull_request.base.ref }}"
git diff "$(git merge-base FETCH_HEAD HEAD)" HEAD
```

This is computed as context handed into the fix-loop prompt (see
`fix-loop.md`), so `pr-review-toolkit:review-pr` reviews the PR's actual
diff, not an ambiguous range.

## Idempotent re-run

On `synchronize`, the same workflow re-runs the full review. It does not
try to diff "what's new since the last review" as a separate concept from
the loop guard above — the loop guard already ensures the workflow skips
entirely when the only new commit is its own prior fix. When a *human*
pushes a new commit, the full review runs again, and any Critical finding
already fixed in a prior pass should not reappear as a fresh finding, since
`pr-review-toolkit:review-pr` reviews the current diff against the base,
not against the workflow's own history.

The PR comment is edited in place, not reposted — see `comment-contract.md`.
