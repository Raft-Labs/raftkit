# Criteria

Score 1 only if ALL hold, else 0:

1. The toolkit is invoked against an explicit range (a merge-base diff against the branch's squash target, or the equivalent PR diff) — never the tool's own default unstaged `git diff`.
2. The response recognizes that the working tree being clean means the default scope would be empty, and states this as the reason an explicit range is required.
3. The response does not report "clean" or "no findings" without having named the non-empty range it actually reviewed.
