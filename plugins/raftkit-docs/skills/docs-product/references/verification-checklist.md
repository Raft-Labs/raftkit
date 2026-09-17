# Verification checklist — graded gaps and the done-claim gate

Two instruments share this file: the post-generation checklist (Phase 10) and
the category-graded validation gate that fires on any done/merge/ship claim.
Both produce graded findings — P0 (blocks done), P1 (should fix), P2
(cosmetic) — and neither ever declares done on a P0 blocker or without the
developer's approval. `scripts/validate-docs.mjs --graded` emits the same
P0/P1/P2 grading deterministically; its exit contract is unchanged.

## Post-generation checklist (Phase 10)

- Structural completeness — every foundation doc the convention expects.
- Per-module completeness — overview, features, APIs, schemas, workflows,
  observability, test plan; conditional docs where the design requires them.
- Edge-case coverage — every walked category answered or `N/A — <reason>`.
- Cross-references resolve; index registries list every doc.
- Code-sample archetype consistency — never mixed.
- Diagram coverage per the catalog, with recorded N/A reasoning.
- Docs-vs-code diff where code exists.

Output: a graded gap report (P0/P1/P2) handed to the human-gated refinement
loop (Phase 11).

## The done-claim gate (category-graded)

When the developer claims a feature or module is done, compare spec against
implementation across these categories, one verdict each:

1. pages/screens · 2. UI components and their states · 3. wired actions ·
4. API procedures and shapes · 5. schema parity · 6. state machines ·
7. async jobs · 8. webhooks · 9. edge-case code paths · 10. telemetry
events firing · 11. permissions vs the RBAC matrix · 12. i18n keys ·
13. compliance/PII handling · 14. tests for critical paths · 15. diagrams
accurate.

Report format: per-category verdict with evidence, then blockers (P0) and
warnings (P1/P2). A failed gate loops back into the owning fix path — code,
spec, or a documented deferral; never a silent skip.

**Override rule:** a logged override (recorded with its reason in the change
history) keeps the module status Draft and never promotes it to Implemented;
the known gaps are recorded alongside.

Grading contract (kept on single lines for tooling):

- Findings across pages, components, actions, APIs, schema, state machines, jobs, webhooks, edge cases, telemetry, permissions, i18n, compliance, tests, and diagrams are graded P0 then P1 then P2.
- A logged override keeps the module status Draft (it stays Draft, never Implemented), and done is refused on any P0.
