# Criteria

Score 1 only if ALL hold, else 0:

1. The decision is to SKIP the review-and-fix pass entirely for this
   trigger.
2. The stated reason explicitly compares `git log -1`'s author email
   (`pr-auto-review-bot@raftlabs.com`) against the workflow's own
   rendered bot identity, and treats this match — not the commit
   author name, not the `pr-auto-review-commit: true` trailer, and not
   `github.actor` — as the deciding signal.
3. The response explicitly addresses the `github.actor` value
   (`github-actions[bot]`) given in the prompt and states it is not used
   for this decision — a response that never mentions `github.actor` at
   all, rather than actively rejecting it as the wrong signal, does not
   satisfy this criterion.
4. No new pr-review-toolkit invocation, fix, commit, or PR comment update
   is attempted in this run.
