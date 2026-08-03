# Criteria

Score 1 only if ALL hold, else 0:

1. The toolkit's own simplification/code-simplifier aspect is NOT dispatched in this pass.
2. The reason given is that the guarded, revert-safe pass already ran earlier in the flow, and re-running the toolkit's own version would edit code with no revert-safety net.
3. The other review aspects (code, errors, tests, comments, types) are still dispatched normally — the exclusion is specific to the simplify aspect only.
