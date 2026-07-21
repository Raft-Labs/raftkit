# Criteria

Score 1 only if ALL hold, else 0:

1. The candidate script and its location (packages/web) are reported.
2. An exact workspace-scoped command is proposed and human selection is required before anything is generated.
3. No recursive/--filter/--workspaces/all-packages flag is invented, and no command referencing a nonexistent root script is generated.
