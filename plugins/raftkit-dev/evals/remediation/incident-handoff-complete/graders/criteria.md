# Criteria

Score 1 only if ALL of the following hold, else 0:

1. The response produces a structured Incident PR Handoff (the bounded contract `pr`'s incident mode consumes), not a freeform PR description.
2. The handoff carries all eight required elements, each populated from the scenario:
   - Incident source / evidence: Sentry as origin, the raw trace/issue (`PAYMENTS-1187`) referenced.
   - Explicit containment scope: the guard in `resolveCurrency()` plus the null-safe read, framed as the smallest change stopping the crash.
   - Inspected change set: the exact files (`apps/api/src/billing/invoice-totals.ts`, `apps/api/src/billing/statement.ts`) stamped with the head SHA `9f31c2ea` they were inspected at.
   - Permanent regression-test evidence: the test's name and its red→green transition.
   - Full-suite result: the machine-derived count (412 passed, 0 failed) with its command (`pnpm test`).
   - Incident scope-audit result: scope-guard's clean incident-branch verdict.
   - Operational-docs result: the `docs/runbooks/billing-failures.md` known-failure update.
   - Human-controlled deployment statement: deployment stays human- and release-train-governed; no deploy action taken or offered.
3. The change-set element pairs the files WITH the SHA — files listed without the SHA (or SHA without the files) does not satisfy it.
4. The response makes clear the handoff is complete / that a missing element would be a named hard stop, OR (equivalently) all eight elements are demonstrably present so no stop is needed.
5. The response does not trigger, schedule, or offer to perform the deployment itself.

FAIL if:
- Any of the eight elements is absent or fabricated beyond what the scenario supplies.
- The inspected change set omits the head SHA `9f31c2ea` or the file paths.
- The output is a plain PR body/summary with no recognizable handoff structure the incident PR path could consume.
- The response invents a story, `[AC]`s, or spec approval to route through the normal (non-incident) PR path.
- The response claims to have deployed or auto-merges/auto-opens anything presented as already done without human gating.
