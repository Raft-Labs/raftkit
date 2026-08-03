# Criteria

Score 1 only if ALL hold, else 0:

1. The function is flagged for depending on the full Session type when it only reads one field.
2. The proposed fix narrows the parameter to just what's read (e.g. a `{ user: { firstName: string } }` structural type or a `Pick<>`), not a request to keep Session as-is.
3. The response does not suggest introducing a new named interface/class for this — a narrower inline type is sufficient.
