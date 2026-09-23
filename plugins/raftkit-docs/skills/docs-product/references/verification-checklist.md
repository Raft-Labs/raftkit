# Verification checklist — graded gaps after generation

The post-generation checklist (Phase 10) produces graded findings — P0
(blocks done), P1 (should fix), P2 (cosmetic) — and never declares a
generated doc set done on a P0 blocker. `raftkit-dev:docs`'s
`scripts/validate-docs.mjs --graded` emits the same P0/P1/P2 grading
deterministically; its exit contract is unchanged. A done claim on a code
change set is verify mode, which is `raftkit-dev:docs`.

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
