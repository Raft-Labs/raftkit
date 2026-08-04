# The PR comment contract

One comment per PR, edited in place on every re-run — never a fresh comment
each time, never filed to Asana.

## When it is written

**Before the first fix, not after the last one.** The fix loop pushes commits
one at a time and would otherwise write its summary only at the very end, so
a run that dies to `--max-turns` or `timeout-minutes` mid-loop would leave
bot commits on the branch with no comment at all — no fix list, no unverified
disclosure. The one mandatory safety artifact would be the one thing skipped.

So the order is fixed:

1. Create or update the marker comment with the finding list, the tier
   disclosure, and `Fix loop in progress — this comment is updated after each
   pushed commit.`
2. Apply, verify, commit, push one fix.
3. Update the comment with that fix's line.
4. Repeat from 2.

The workflow adds an `if: always()` backstop step behind all of this: if the
run terminates before it ever completes, that step appends a **"Run
terminated early … commits may already be present on this branch without a
complete summary"** line to the marker comment, creating the comment if the
run died before even step 1.

## Finding the comment to edit

The comment's first line is a hidden HTML-comment marker:

```
<!-- raftkit:pr-auto-review-summary v1 -->
```

On each run, list the PR's comments and find the one whose body starts with
this exact marker, capturing its `id`. **Paginate the listing.** GitHub
returns 30 comments per page; a PR on a repo that runs review bots routinely
carries more than that, and reading only page 1 misses the marker and POSTs a
duplicate comment on every single run — exactly the failure this contract
exists to prevent:

```bash
gh api --paginate "repos/$OWNER_REPO/issues/$PR_NUMBER/comments" \
  --jq "[.[] | select(.body | startswith(\"<!-- raftkit:pr-auto-review-summary v1 -->\"))] | last | .id // empty"
```

The issue-comments API has no server-side body filter, so the marker match
happens in the `--jq` expression — but `--paginate` runs it over every page,
not just the first.

**Edit via the per-comment endpoint, not the list endpoint** — GitHub's
edit call is `PATCH repos/{owner}/{repo}/issues/comments/{comment_id}`,
keyed by that comment's own `id`; it never includes the PR number in its
path. Using the list/create path (`issues/{pr}/comments`) for the edit is a
404, and a naive fallback from that 404 would silently `POST` a fresh
comment every run. If no comment with the marker exists yet (first run on
this PR), `POST` a new one to `issues/{pr}/comments`, carrying the marker as
its first line.

Pass the body from a file (`-F body=@<file>`), never as an inline argument.

## Contents, in order

1. **Fixed findings**, each as one line with a commit link:
   ```
   - [<finding file>:<finding line>](<commit URL>): <one-line summary of the fix>
   ```
   `<commit URL>` is `https://github.com/{owner}/{repo}/commit/<full SHA>` —
   the full 40-character SHA of the fix commit, captured **after** its push
   exited 0 (`fix-loop.md` step 3.d). A SHA captured before a confirmed push
   can link a commit that never reached the remote.
2. **The CI-coverage disclosure**, on every run that pushed at least one
   commit. GitHub does not trigger workflow runs for pushes made with
   `GITHUB_TOKEN` (see `workflow-mechanics.md`), so the repo's own tests
   never ran against these commits and a green check on the PR does not
   cover them. The reviewer has to be told that in the artifact they are
   reading:
   ```
   These commits were pushed by CI and have NOT been exercised by this
   repository's own workflows — GitHub does not trigger workflow runs for
   pushes made with GITHUB_TOKEN. Review them before merging; a green check
   on this PR does not cover them.
   ```
3. **Important/Suggestion findings**, each as one line:
   ```
   - <file>:<line> — <finding text, verbatim from pr-review-toolkit>
   ```
   If none exist, omit this section entirely rather than printing an empty
   heading — symmetric with the zero-Critical-findings case below, which
   states its own empty-state text explicitly instead of leaving a blank
   section.

   **Size cap.** A GitHub comment body cannot exceed 65536 characters. A body
   over the cap returns 422 and the comment is lost entirely — with commits
   already pushed and nothing on the PR to disclose them. So the body is
   capped at 60000 characters: include as many *complete* findings as fit,
   write the remainder to the job summary (`$GITHUB_STEP_SUMMARY`), and say
   so explicitly:
   ```
   Truncated to fit GitHub's comment size limit — <N> of <M>
   Important/Suggestion findings are shown above. The complete list is in
   this run's job summary (Actions → this run → Summary).
   ```
   Never drop a finding silently, and never truncate an individual finding's
   text — whole findings are omitted and counted, never abridged.
4. **Verify-tier disclosure**, whenever Tier 2, Tier 3, a red baseline, or an
   infrastructure failure applied (see `fix-loop.md`) — the exact strings
   from that file, never paraphrased. The baseline-red and infrastructure
   strings are distinct from the no-script Tier 3 string on purpose: "there
   was nothing to run", "it was already failing before we started", and "the
   harness itself is broken" are three different things a reviewer needs to
   tell apart.
5. **Zero-Critical-findings case** — when nothing was fixed, the comment
   still posts (or still edits in place), with the exact string:
   ```
   No critical issues found.
   ```
   followed by the Important/Suggestion section (empty or populated) as
   above. Comment even when fully clean — silence must never be mistaken
   for "the workflow didn't run."
6. **Stop reasons**, when they apply: any "Could not auto-fix safely" line
   from a red fix, and the "review could not be completed" line when
   `pr-review-toolkit:review-pr` did not return a structured finding list.

   **Push failures get a disclosure that names the remote state**, not just
   the fact of failure. A non-fast-forward rejection is the likely case, but
   auth errors, pre-receive hooks, protected-branch rules and network
   failures all reach here too — and a network failure after the objects
   transferred can leave the commit on the remote while reporting failure.
   So the line states the reason *and* what the run confirmed via
   `git ls-remote`:
   ```
   Fix loop stopped early — `git push` failed (<reason from git's output>).
   Commit <short SHA> <is / is NOT> present on the remote branch. Nothing
   was force-pushed and no history was rewritten. The remaining Critical
   findings below are unaddressed.
   ```
   A reviewer must never have to open the Actions log to find out whether a
   commit landed.

## Marker versioning

The `v1` in the marker is a template-version tag, not a run counter — it
stays `v1` until this contract's comment shape changes incompatibly enough
that an old-format comment shouldn't be matched and edited in place (e.g. a
future reordering of the sections above). A version bump means finding
comments by the *old* marker separately from the new one, so an in-flight
PR with an old-format comment gets a fresh new-format one rather than a
corrupted in-place edit — that migration mechanic is out of scope until a
`v2` is actually needed.

## What this contract replaces

There is no chat session in headless CI, so this comment **is** the
draft-then-approve gate's replacement — see `raftkit-core/write-protocol`'s
"The two documented exceptions" (entry 2, pr-auto-review) section for why this satisfies
the spirit of that gate rather than bypassing it.
