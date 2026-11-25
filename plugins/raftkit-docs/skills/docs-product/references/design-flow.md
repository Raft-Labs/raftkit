# Design flow

Twelve phases, in order. Never skip one; refuse a jump in one line. Load only the reference the phase needs. Every question follows `interview.md`.

## Entry

- Greenfield → phase 1.
- Existing code → offer reverse-engineering (Recommended), a fresh design, or a hybrid (`existing-docs.md`).
- Resume → continue from the recorded phase. Never re-ask an answered question.

## Phases

1. **Classify** the project type; confirm it.
2. **Business context** — persona, launch markets, regulation, scale at six months, pricing.
3. **Stack** — recommend one archetype with its reasoning and caveats. Flag picks known to fail.
4. **Auth, tenancy, roles** — exits only with a drafted RBAC matrix.
5. **Module inventory** — propose a grouping. Volunteer forgotten modules: notifications, audit log, API keys, webhooks, integrations.
6. **Per-module loop**, one module at a time.
7. **Cross-cuts** — async and scheduling; AI and realtime; distribution (web, mobile, push, updates); compliance and PII, never skipped; NFRs (latency, throughput, RPO/RTO, regions, on-call); integrations (OAuth in, services out, payments, webhooks both ways).
8. **Confirmation** — full recap. Nothing is generated before the developer signs off.
9. **Generation** — `generation.md`.
10. **Verification** — the graded check in `generation.md`. Never done on a P0.
11. **Refinement** — show the gap list and ask which to fix now. Module gaps return to phase 6, cosmetic ones to phase 9. Ends only when the developer says it is good enough.
12. **Scaffolding**, optional — `scaffolding.md`.

After generation, `raftkit-dev:docs` keeps the docs in step with the code.

## Per-module loop

Walk each step, or mark it `N/A — <reason>`:

1 purpose and owner · 2 pages and screens · 3 components per page · 4 actions beyond CRUD · 5 API procedures · 6 tables · 7 end-to-end wiring · 8 state machine · 9 events, async, webhooks · 10 edge cases, walked · 11 empty, loading, error and offline states · 12 telemetry · 13 accessibility · 14 locale and translation · 15 feature flags and rollout · 16 responsive breakpoints · 17 copy · 18 URL state and navigation · 19 performance budget · 20 SEO, public pages only · +1 compliance, PII, retention, deletion and the test plan, always.

A module locks on mutual agreement. Post a self-assessment with a count per step, then ask: "Anything to add or revise before the next module?" Lock only on the developer's yes.

After the last module, reconcile: one shape per shared entity, one answer per shared role, a consumer for every emitted event, one shared doc per shared integration.

## RBAC matrix

Confirm the role list, then draft three levels in order:

1. Role × module — visibility: full, own records, partial, blocked.
2. Role × module × action — capability, reads included.
3. Role × field — sensitive fields only.

A stub scaffold is acceptable; no matrix is not. Flag: one "user" role with feature flags as permissions; permissions checked inline in handlers instead of middleware; reads left out; a matrix the code does not enforce.
