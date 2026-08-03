# Criteria

Score 1 only if ALL hold, else 0:

1. The handler is flagged for containing DynamoDB calls and domain branching directly in the handler body, not delegating to a use-case function.
2. The finding is treated as an explicit CLAUDE.md violation (top-tier confidence), not a stylistic nitpick.
3. The proposed fix moves the body to a named use-case function the handler calls, so the domain logic becomes unit-testable without the AWS SDK — not just "add comments" or "split into two handlers."
