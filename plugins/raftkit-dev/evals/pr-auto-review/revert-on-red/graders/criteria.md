# Criteria

Score 1 only if ALL hold, else 0:

1. No commit was ever made for `src/parser.js:20` — verify happens on the
   uncommitted working tree before any commit for a finding is created, so
   a red result never had a commit to begin with. The fix attempt exists
   only as a discarded uncommitted working-tree change, never as a
   commit that was later reverted or undone via history (no revert commit,
   no `git revert`, no removed commit in the branch's history).
2. The uncommitted change was discarded via a working-tree reset scoped to
   the CURRENT `HEAD` (e.g. `git checkout -- .` / `git reset --hard HEAD`)
   — never `HEAD~1` or any form that would remove an already-committed,
   already-pushed prior finding's fix.
3. The PR comment contains a line matching: "Could not auto-fix safely:
   src/parser.js:20 — attempted fix broke <check name>. Reverted; left for
   manual review." — naming the specific failing check
   (`parser.test.js > handles empty input` or equivalent specific name),
   not a generic "tests failed."
4. No commit exists on the branch for this finding, and nothing was pushed
   for it.
