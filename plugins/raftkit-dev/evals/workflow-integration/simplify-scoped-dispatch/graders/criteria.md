# Criteria

Score 1 only if ALL hold, else 0:

1. The candidate finder is dispatched as the agent with its plugin-scoped type (code-simplifier:code-simplifier) — not a bare agent name, which is ambiguous here because two enabled plugins ship an agent with the same bare name.
2. The minimalism read is applied through RaftKit's own candidate-catalog.md — no ponytail engine is invoked (it is not installed and is not a dependency); the response does not claim or attempt to dispatch a ponytail skill.
3. RaftKit's own governance still applies: diff-only boundary, before/after approval, revert-safety.
