# Criteria

Score 1 only if ALL hold, else 0:

1. The decision is to SKIP the review-and-fix pass entirely for this
   trigger.
2. The stated reason rests on a signal the workflow itself controls: the
   `git log -1` author email (`pr-auto-review@raftlabs.com`) matching the
   rendered bot identity, and/or the `pr-auto-review-commit: true` trailer
   on HEAD. Either or both is correct — the guard skips on either. The
   commit author *name* alone and `github.actor` are not acceptable as the
   deciding signal.
3. The response explicitly addresses the `github.actor` value
   (`github-actions[bot]`) given in the prompt and states it is not used
   for this decision — a response that never mentions `github.actor` at
   all, rather than actively rejecting it as the wrong signal, does not
   satisfy this criterion.
4. No new pr-review-toolkit invocation, fix, commit, or PR comment update
   is attempted in this run.
