# Workflow mechanics — trigger, loop guard, toolchain, diff anchoring, idempotent re-run

## The limitation to read first: pushes by `GITHUB_TOKEN` do not run CI

GitHub deliberately suppresses workflow runs for events generated with the
built-in `GITHUB_TOKEN`, to stop workflows triggering themselves recursively.
This workflow pushes its fix commits with that token, so **the repo's own
test, lint and guardrail workflows never run against the SHA this bot
pushed.** A PR can therefore show a green check that was computed on the
commit *before* the bot's fixes.

Consequences, all of them load-bearing:

- The PR summary comment states this explicitly on every run that pushed a
  commit (see `comment-contract.md`) — the human reviewer is told, in the
  artifact they are reading, that the bot's commits are not CI-exercised.
- The bot's own in-job verification (`fix-loop.md`) is the only automated
  check those commits ever get. That is why the dependency-install step
  below is not optional: without it there is no verification at all.
- **The bot-commit loop guard below is currently defence-in-depth, not the
  thing preventing recursion** — with `GITHUB_TOKEN` the bot's push does not
  raise a `synchronize` event in the first place. Do not delete the guard as
  dead code. It becomes load-bearing the moment anyone swaps in a GitHub App
  token or a PAT (see `install.md`'s optional upgrade path), and it is also
  what makes a re-run over a branch that already carries bot commits a
  no-op.

RaftKit's shipped configuration takes the no-new-secrets path: `GITHUB_TOKEN`
only, this limitation documented and disclosed, no PAT and no App private key
added to a client repo.

## Trigger

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
```

`synchronize` is the core case — re-review on every push to the PR, not just
once at open. `reopened` re-reviews a PR that was closed and reopened.
`ready_for_review` exists because of the draft guard below: without it, a PR
opened as a draft and later marked ready would never be reviewed at all.

## Fork and draft guard — job level, not step level

```yaml
if: >-
  github.event.pull_request.head.repo.full_name == github.repository &&
  github.event.pull_request.draft == false
```

Both conditions sit on the **job**, so no step can ever precede them.

- **Fork guard** — pairs with the `pull_request` trigger (see the asset's
  SECURITY header): a fork PR runs nothing at all.
- **Draft guard** — a draft PR is a developer's own workspace. They open it
  for early CI, keep force-pushing, and rebase freely. A bot commit landing
  on top means their next push is rejected non-fast-forward, they force-push,
  the fix vanishes, and the summary comment links an orphaned commit. Drafts
  are excluded until the author marks the PR ready.

## Concurrency

`concurrency` is keyed on the PR number, so a rapid double-push doesn't run
two fix loops against the same PR simultaneously and race each other's
commits — but it **serializes rather than cancels**:

```yaml
concurrency:
  group: pr-auto-review-${{ github.event.pull_request.number }}
  cancel-in-progress: false
```

`false` is load-bearing. This job pushes each fix to its own trigger branch
(`fix-loop.md` step 3d pushes per-fix, not batched at the end). Under
`cancel-in-progress: true`, if anything ever *did* re-trigger the workflow
mid-run, the run would cancel *itself* right after its first pushed fix —
every remaining Critical finding dropped, and the end-of-run PR summary
comment (`comment-contract.md`) never posted.

A *human* push mid-run is the case this costs something: the in-flight run is
now working from a stale head, and its push is rejected non-fast-forward.
The fix loop is required to stop there and say so in the comment — never
pull-rebase, never force-push (`fix-loop.md`). The next push reviews the new
head from scratch.

## The self-trigger loop guard

Every fix commit this workflow makes carries a `pr-auto-review-commit: true`
trailer in its commit message body (see `fix-loop.md`) **and** the rendered
bot author identity, stamped by the `Configure bot git identity` step below.
Before invoking the official action, a guard step checks **both**, and skips
on either:

```yaml
- name: Check last commit is not our own fix
  id: guard
  run: |
    AUTHOR_EMAIL="$(git log -1 --pretty=format:'%ae')"
    TRAILER_HITS="$(git log -1 --pretty=format:'%B' | grep -c '^pr-auto-review-commit: true[[:space:]]*$' || true)"
    if [ "$AUTHOR_EMAIL" = "__BOT_COMMIT_EMAIL__" ] || [ "$TRAILER_HITS" -gt 0 ]; then
      echo "skip=true" >> "$GITHUB_OUTPUT"
      # ... and write the reason to $GITHUB_STEP_SUMMARY
    else
      echo "skip=false" >> "$GITHUB_OUTPUT"
    fi
```

Every subsequent step (including the `anthropics/claude-code-action@v1`
invocation) is gated `if: steps.guard.outputs.skip != 'true'`.

**Why two signals, not one.** The author email alone was a blind spot: `git
rebase` preserves the author, so a human who rebases their branch and lands
with a bot commit last would make the guard skip — and their own new commits
would never be reviewed. The trailer alone is not enough either: a squash or
an amend can drop the message body while keeping the author. Checking both,
skipping on either, is the conservative combination.

**Why the commit author identity, not `github.actor`:** `github.actor`
reflects the push event's actor, which — depending on whether a GitHub App
token or a PAT was used to push the fix commit — can read ambiguously. The
commit author identity is fully controlled by this workflow itself, so it's
the one signal that's reliable regardless of token/App identity used for the
push.

## Bot git identity — required, and the reason the email signal works

```yaml
- name: Configure bot git identity
  if: steps.guard.outputs.skip != 'true'
  run: |
    git config user.name "__BOT_COMMIT_NAME__"
    git config user.email "__BOT_COMMIT_EMAIL__"
```

Not optional, and load-bearing twice. A GitHub Actions runner carries no
default git identity, so without this step every `git commit` in the fix loop
fails with `Please tell me who you are` and no fix can ever be committed — the
workflow runs and accomplishes nothing. It is also the only reason the guard's
author-email comparison above ever matches: without it the bot's commits do
not carry `__BOT_COMMIT_EMAIL__`, and that half of the guard silently degrades
to never firing, leaving the trailer — defence-in-depth by design — as the
sole signal.

**A skip is never silent.** The guard writes its reason (the observed author
email and trailer count) to `$GITHUB_STEP_SUMMARY`, so a run that exits as a
no-op is visibly a deliberate skip and not a broken workflow.

`__BOT_COMMIT_EMAIL__` is a rendered token whose canonical value is
`pr-auto-review@raftlabs.com` — pinned as the renderer's default and
documented in `install.md`, never invented per install.

## Toolchain and dependency install

```yaml
- name: Set up Node toolchain
  if: steps.guard.outputs.skip != 'true' && hashFiles('package.json') != ''
  uses: actions/setup-node@v4
  with:
    node-version: lts/*

- name: Install dependencies
  id: deps
  ...
```

Without this, the fix loop resolves Tier 1, runs the repo's `test` script
against a checkout with no `node_modules`, and reads the module-not-found
failure as "this fix is red" — discarding a correct fix, on every finding, in
every repo. Verification could never pass.

The install step **never fails the job**. It records a status the prompt
reads via the `DEPS_STATUS` environment variable:

| `DEPS_STATUS` | Meaning | Fix loop's response |
|---|---|---|
| `ok` | Dependencies installed | Resolve a tier normally |
| `none` | No `package.json` at all | Tier 3 (nothing runnable) |
| `unsupported` | A non-npm lockfile (pnpm/yarn/bun) | Abort: cannot verify, disclose |
| `failed` | `npm ci`/`npm install` exited non-zero | Abort: cannot verify, disclose |

`unsupported` is deliberate. Running `npm ci` against a pnpm or yarn tree
produces a failure that has nothing to do with the code under review;
reporting "cannot verify" is honest, guessing is not. Adding first-class
pnpm/yarn/bun install support is a known gap, not a bug.

## Identifiers come from the event, never from `gh pr view`

The job passes `OWNER_REPO`, `PR_NUMBER`, `HEAD_REF` and `BASE_REF` into the
prompt as environment variables, sourced from `github.repository` and
`github.event.pull_request.*`. `GH_TOKEN` is set from `github.token` at job
level — without it every `gh` call in the prompt fails and the summary
comment, the workflow's one mandatory safety artifact, is never posted.

Auto-detection is banned in the prompt because `gh pr view` resolves by
branch, and a branch with two open PRs — one into `main`, one into
`development`, standard on a release-train repo — resolves ambiguously. The
unverified-code disclosure would land on the wrong pull request.

## Diff anchoring

`actions/checkout` runs with `fetch-depth: 0`, which fetches every branch, so
the base ref's remote-tracking branch already exists and the merge-base
resolves directly:

```bash
git merge-base "origin/$BASE_REF" HEAD
```

There is deliberately **no separate base-branch fetch step**. The one that
used to exist was redundant, and it interpolated
`${{ github.event.pull_request.base.ref }}` straight into a `run:` block —
branch names may contain backticks, `$`, `;` and `&`, and those expand inside
double quotes in a job holding `contents: write` and `ANTHROPIC_API_KEY`. The
base ref now travels through `env:` and is only ever referenced as
`"$BASE_REF"`. If a repo ever lands in a state where `origin/$BASE_REF` does
not resolve, the prompt fetches it once — from the quoted variable, never
from a template interpolation.

## Early-termination backstop

The fix loop pushes commits incrementally but writes its complete summary at
the end, so exhausting `--max-turns` or `timeout-minutes` after a push would
leave the branch carrying bot commits with no disclosure at all. Two things
prevent that:

1. The prompt posts the marker comment **before** the first fix and updates
   it after each pushed commit (`fix-loop.md`, `comment-contract.md`).
2. A final `if: always()` step appends a "run terminated early — commits may
   be present without a full summary" line to the marker comment (creating
   it if the run died before step 1) whenever the fix-loop step did not
   record completion.

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
