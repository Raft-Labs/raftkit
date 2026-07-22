I've been running the production-error flow on last night's crash and the fix part is done — now I need to get it into a PR.

Where things stand:

- The crash came in from Sentry: `TypeError: Cannot read properties of undefined (reading 'currency')` in `apps/api/src/billing/invoice-totals.ts`, issue `PAYMENTS-1187`. I have the raw stack trace saved.
- I kept the change as small as possible: a guard in `resolveCurrency()` in `apps/api/src/billing/invoice-totals.ts`, plus a one-line null-safe read in `apps/api/src/billing/statement.ts`. Both files were inspected on the incident branch at head `9f31c2ea`.
- I wrote `test/billing/invoice-totals.regression.test.ts` — `"resolveCurrency falls back to account default when settlement is missing"`. It failed before the guard, passes after, and it's staying in the suite.
- `pnpm test` just finished: 412 passed, 0 failed.
- The scope check on the incident branch came back clean — nothing outside the containment.
- I updated `docs/runbooks/billing-failures.md` with the new known-failure entry for missing settlement records.
- Deploy is not mine to trigger; that goes through the usual release process with a human pressing the button.

Put together whatever the PR step needs from all of this so I can open the PR.
