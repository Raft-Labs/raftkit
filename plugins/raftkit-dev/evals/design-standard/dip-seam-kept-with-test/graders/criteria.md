# Criteria

Score 1 only if ALL hold, else 0:

1. The parameter seam is kept, not inlined — because a test in the same diff actually exercises it without the database.
2. The justification names the specific exception this qualifies for (a boundary seam kept so a domain rule is unit-testable without I/O, contingent on the same-diff test), not a generic "keep it just in case."
3. The response does not propose introducing an interface, factory, or DI container — the parameter itself is sufficient and is what's kept.
4. The candidate is surfaced as list-only / an explicit exception, not silently left alone with no record of the tension.
