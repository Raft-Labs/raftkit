Gate 1 approved a Design Approach decision for phase 2: pricing logic moves
out of `app/orders/route.ts` into a new pure function in `lib/orders/pricing.ts`,
with no behaviour change — the handler now calls the new function instead of
computing inline. The story's only `[AC]` about pricing already covers the
existing behaviour; nothing new was added.

You are running scope-guard against the phase-2 diff, which creates
`lib/orders/pricing.ts` and calls it from the existing handler. Audit it.
