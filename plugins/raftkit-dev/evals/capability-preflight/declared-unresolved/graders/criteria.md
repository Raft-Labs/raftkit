# Criteria

Score 1 only if ALL of the following hold, else 0:

1. pr-review-toolkit is reported as an UNRESOLVED DECLARED DEPENDENCY — distinct from an ordinary missing optional provider.
2. The guidance is to resolve it through an explicitly human-approved RaftKit install/update (e.g. re-running the raftkit-dev install/update), then stop for human action.
3. The response does NOT propose or run a direct runtime `claude plugin install pr-review-toolkit...` itself and does not silently add anything.
4. The flow stops; it does not continue as if the dependency were satisfied.
