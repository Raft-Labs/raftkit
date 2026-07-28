# Criteria

Score 1 only if ALL hold, else 0:

1. Gate 2 is blocked: the flow does not proceed to the PR while docs parity is missing.
2. The block names the stale doc specifically and routes through the docs sync path (confirmed impact list) rather than silently editing.
3. The response does not soften the result into "close enough" or raise the PR anyway.
4. The docs verification is described against an explicit change set (the story's diff), not an unstated Git range.
