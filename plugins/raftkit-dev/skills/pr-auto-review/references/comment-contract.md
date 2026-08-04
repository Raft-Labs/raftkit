# The PR comment contract

One comment per PR, edited in place on every re-run — never a fresh comment
each time, never filed to Asana.

## Finding the comment to edit

The comment's first line is a hidden HTML-comment marker:

```
<!-- raftkit:pr-auto-review-summary v1 -->
```

On each run: list the PR's comments via
`gh api repos/{owner}/{repo}/issues/{pr}/comments`, find the one whose body
starts with this exact marker, and capture its `id` from that listing.
**Edit it via the per-comment endpoint, not the list endpoint** — GitHub's
edit call is `PATCH repos/{owner}/{repo}/issues/comments/{comment_id}`,
keyed by that comment's own `id`; it never includes the PR number in its
path. Using the list/create path (`issues/{pr}/comments`) for the edit is a
404, and a naive fallback from that 404 would silently `POST` a fresh
comment every run — exactly the duplicate-comment failure this contract
exists to prevent. If no comment with the marker exists yet (first run on
this PR), `POST` a new one to `issues/{pr}/comments`, carrying the marker as
its first line.

## Contents, in order

1. **Fixed findings**, each as one line with a commit link:
   ```
   - [<finding file>:<finding line>](<commit URL>): <one-line summary of the fix>
   ```
   `<commit URL>` is `https://github.com/{owner}/{repo}/commit/<full SHA>` —
   the full 40-character SHA of the fix commit just pushed in `fix-loop.md`
   step 3.d (capture it immediately after that commit, e.g. via
   `git rev-parse HEAD`, before moving to the next finding).
2. **Important/Suggestion findings**, each as one line:
   ```
   - <file>:<line> — <finding text, verbatim from pr-review-toolkit>
   ```
   If none exist, omit this section entirely rather than printing an empty
   heading — symmetric with the zero-Critical-findings case below, which
   states its own empty-state text explicitly instead of leaving a blank
   section.
3. **Verify-tier disclosure**, only when Tier 2 or Tier 3 applied (see
   `fix-loop.md`) — the exact strings from that file, never paraphrased.
4. **Zero-Critical-findings case** — when nothing was fixed, the comment
   still posts (or still edits in place), with the exact string:
   ```
   No critical issues found.
   ```
   followed by the Important/Suggestion section (empty or populated) as
   above. Comment even when fully clean — silence must never be mistaken
   for "the workflow didn't run."

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
