# Orchestration — the design flow as a state machine

The design flow is a 12-phase co-authored state machine. Phases are never
skipped; jumping ahead is refused with a one-line explanation. The next
question always depends on the previous answer. Load only the reference the
current phase needs (progressive disclosure).

## Entry branches

- **Greet → Phase 1** — greenfield design from scratch.
- **Existing repo** — preflight detected code: offer reverse-engineer
  (recommended), fresh design, or hybrid; reverse-engineering runs the same
  per-module loop code-first (`reverse-engineer.md`).
- **Resume** — an interrupted session resumes from the recorded phase without
  repeating answered questions; any modification of previously generated
  material enters change-tracking mode strictly.

## The phases

1. **Classify the project** — one of the project types, inferred confidently
   where evidence allows, confirmed with the developer.
2. **Business context** — persona, geography, regulatory constraints, realistic
   scale, pricing (`discovery-questions.md`; push-back on vague answers per
   `raftkit-core/discovery-interview`).
3. **Stack archetype** — decision tree, recommendation-first with reasoning
   and caveats (`stack-and-domain-recipes.md`).
4. **Auth, tenancy, roles, RBAC** — the auth phase cannot exit without a
   drafted matrix (`rbac-guide.md`).
5. **Module inventory** — propose grouping; volunteer commonly-forgotten
   modules (`module-decomposition.md`).
6. **Per-module deep dive** — the 20+1-step loop, one module at a time; a
   module exits only on mutual agreement backed by a counted self-assessment.
7. **Cross-cuts** — async, AI/realtime, distribution, compliance/PII (never
   skipped), NFR, integrations.
8. **Confirmation pass** — full recap; generation is blocked until the
   developer signs off. No doc file is written before the human sign-off.
9. **Generation** — the adaptive tree per `generation.md`, diagrams per
   `diagram-catalog.md`, archetype-consistent code samples, never mixed.
10. **Verification** — the graded P0/P1/P2 checklist
    (`verification-checklist.md`); never declared done on P0 blockers.
11. **Refinement** — human-gated: present the gap list, ask which to fix now;
    chosen gaps route back to Phase 6 (module-level) or Phase 9 (cosmetic).
12. **Scaffolding** — optional (`scaffolding.md`); always asks first.

After generation, change tracking is always on: any later edit re-enters the
seven-step lifecycle (`change-tracking.md`).

## Gates that never move

- The whole interview runs under `raftkit-core/discovery-interview`. That
  contract is in force here in full — how many questions per turn, recommend
  first, push back on vague answers, never interrogate a complete one, scan
  every answer against its catalogs. It is not restated here, because a
  restatement is a copy that drifts.
- Every developer answer is scanned against `stack-anti-patterns.md` as well —
  the stack half of that scan lives here, not in core.
- Module completion is mutual agreement — the skill's self-assessment AND the
  developer's confirmation; only then the next module.
- Refinement ends when the developer says it is good enough — never silently.
