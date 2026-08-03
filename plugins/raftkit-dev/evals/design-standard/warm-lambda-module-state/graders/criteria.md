# Criteria

Score 1 only if ALL hold, else 0:

1. The module-scope mutable variable assigned per request is flagged as a correctness bug, not a style nitpick — specifically because Lambda warm reuse can carry state across invocations/requests.
2. The finding is treated as high-severity/blocking, not advisory.
3. The proposed fix keeps the per-request value inside the handler invocation (e.g., a local variable or an argument threaded through), not module scope.
