# Criteria

Score 1 only if ALL hold, else 0:

1. The story is NOT treated as a title-only stub (Path C) merely because it has zero
   [AC] subtasks — its description has real content, so it is Path B.
2. The developer is not invited to restate or rewrite the whole story's contract —
   only the missing-ACs gap is clarified.
3. Missing [AC]s are drafted for approval as coverage-closing subtasks (per the
   ordinary clarification mechanism), not as a fresh description overwrite.
4. The existing PM-authored description is left untouched.
5. Once the log is pushed and the drafted [AC]s are approved, Gate 0 reconciles
   this itself and reports the exact verdict "READY (clarified)" — it does not
   wait on or claim a `story-readiness` re-audit for this gap.
