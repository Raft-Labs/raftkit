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
starts with this exact marker, and `PATCH` it in place. If none exists yet
(first run on this PR), `POST` a new one carrying the marker as its first
line.

## Contents, in order

1. **Fixed findings**, each as one line with a commit link:
   ```
   - [<finding file>:<finding line>](<commit URL>): <one-line summary of the fix>
   ```
2. **Important/Suggestion findings**, each as one line:
   ```
   - <file>:<line> — <finding text, verbatim from pr-review-toolkit>
   ```
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

## What this contract replaces

There is no chat session in headless CI, so this comment **is** the
draft-then-approve gate's replacement — see `raftkit-core/write-protocol`'s
"The one named exception — pr-auto-review" section for why this satisfies
the spirit of that gate rather than bypassing it.
