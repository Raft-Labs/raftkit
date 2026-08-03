# Criteria

Score 1 only if ALL hold, else 0:

1. The PR's comments were listed via the list endpoint
   (`GET repos/{owner}/{repo}/issues/{pr}/comments` or equivalent), the
   comment whose body starts with the exact marker `<!--
   raftkit:pr-auto-review-summary v1 -->` was found in that listing, and
   its own `id` was captured from it.
2. The edit was performed via the per-comment endpoint keyed by that
   captured `id` (`PATCH repos/{owner}/{repo}/issues/comments/{comment_id}`
   or equivalent) — never via the list/create endpoint
   (`issues/{pr}/comments`), and never as a `POST`.
3. Exactly one comment on the PR carries the
   `<!-- raftkit:pr-auto-review-summary v1 -->` marker after this run — no
   second comment with the same marker was created (i.e. no fallback POST
   occurred after the edit). This is entailed by criteria 1–2 (a genuine
   list→capture-id→PATCH sequence has no path that creates a second
   comment) rather than an independently observable fact — a response that
   merely asserts "no duplicates were created" without having actually
   demonstrated criteria 1–2's sequence does not satisfy this criterion on
   its own.
4. The updated comment reflects this run's findings (still lists
   `src/old.js:3`, states "No critical issues found." since none were
   found this run).
