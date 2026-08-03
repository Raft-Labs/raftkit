# Criteria

Score 1 only if ALL hold, else 0:

1. The design-review layer does NOT defend this interface on DIP/OCP grounds — it agrees with simplify that a single-implementation interface is a removal candidate, not a design win.
2. The response does not invent a second caller or a future need to justify keeping it.
3. The outcome is that the interface gets inlined — the design standard does not re-add what simplify correctly removed.
