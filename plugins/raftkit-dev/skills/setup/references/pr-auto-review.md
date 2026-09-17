# The opt-in PR auto-review workflow

What component 7 installs, and the boundary that makes it the one thing in RaftKit allowed to commit without a per-write approval.

## What it is

A GitHub Actions workflow in the client repo, on `pull_request` opened and synchronize, wrapping `anthropics/claude-code-action@v1` to run `pr-review-toolkit:review-pr` headlessly. It fixes and commits **Critical** findings only, one commit per fix, and reports everything else in a single PR comment edited in place. Rendered by `scripts/render-pr-auto-review.mjs` from `assets/pr-auto-review.yml` and `assets/fix-loop-prompt.md`; the renderer fails closed exactly as the other assets do.

## The boundary

- **May, without asking:** commit one fix per Critical finding, in conventional-commit form, carrying the finding's file and line and a `pr-auto-review-commit: true` trailer, so every write is attributed and revertible.
- **Never:** merge the PR, touch Important or Suggestion findings, push to a protected branch, edit any file under `.github/workflows/` including its own, or write to Asana.
- **The safety net:** every fix is re-verified against the repo's strongest available check. A fix that turns a check red is reverted immediately and named in the comment as one it could not fix safely. With no check at all, the fix still lands but carries a permanent "unverified" disclosure.
- **Why a comment replaces the stop:** the workflow runs headless, with no session to stop in. The PR comment names every commit it made and every finding it did not touch, so the human's merge decision is as informed as an in-session approval would have been.

Nothing beyond this is exempt from the one stop per run. A future mechanism that wants to write on its own needs its own reviewed amendment here, never an inference from this one.

## GITHUB_TOKEN and the bot identity

Pushes made with `GITHUB_TOKEN` do not trigger the repository's own workflows. A fix commit therefore does not re-run the checks on its own push: the workflow verifies each fix itself before committing, and the PR comment discloses that the commit was not exercised by a fresh CI run. A team that wants those runs installs a GitHub App token instead and swaps it into the workflow's checkout step; that is a deliberate change to the rendered file, recorded in the same way as any other edit to a pack-managed file.

Every renderer argument defaults, and the defaults are the canonical values: the commit author is `pr-auto-review@raftlabs.com`, the plugin reference is `pr-review-toolkit@claude-plugins-official`. Nothing is invented at render time and no argument has to be supplied for an ordinary install.

## Install notes

The `ANTHROPIC_API_KEY` repo secret is a manual step: GitHub does not expose secret presence to a read, so this skill cannot verify or create it. The success output prints the exact path to add it as a required next action.

The workflow skips its own commits. The guard fires on either signal the workflow controls: the rendered bot author email, or the `pr-auto-review-commit` trailer on `HEAD`. A human commit after a bot commit still triggers a run.

After any auto-fix commit, the branch head has moved: re-run the scope check before merging, since the diff a human last read is not the diff they would merge.
