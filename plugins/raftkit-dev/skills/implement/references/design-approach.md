# Design Approach — the structural decisions Gate 1 approves

The artifact that makes a story's structural decisions visible and reviewable
**before** any code exists, and gives `scope-guard` a legitimate way to admit a
purely structural hunk instead of fail-closing it into BEYOND. Presented at
Gate 1 alongside the scope contract, the decomposition table, and the Docs
Impact Plan (`references/gates.md`) — a fourth artifact, not a fourth gate.

## The artifact

| # | Decision | Alternative rejected | Why | Phases |
|---|---|---|---|---|
| D1 | Tier rules live in a pure `resolveTier(order, tiers)`; the handler passes the Hasura client in. | Query inside the resolver. | Tier maths is the risky part and must be unit-testable with no DB. | 2, 3 |
| D2 | One Lambda per route, no shared router. | Single fan-out handler. | Cold-start and IAM scope per route; matches the existing `functions/` layout. | 1 |

**Deliberately not doing:** no repository interface (one caller); no
tier-strategy registry (three tiers, a map literal).

Five fields, each earning its place:

1. **Decision** — one sentence naming an actual boundary in this repo. "Single
   Responsibility" is not a decision; "the handler does not talk to Hasura" is.
2. **Alternative rejected** — the anti-ceremony field. It cannot be produced by
   paraphrasing the story; a rejected alternative requires having considered
   the shape of the problem.
3. **Why** — one clause tied to something real: a test seam, an AC, a
   constraint, an existing convention. "Best practice" is rejectable.
4. **Phases** — the decomposition-table row numbers this decision governs.
   This is the **join key** `scope-guard` consumes mechanically
   (`scope-guard/references/audit-method.md`) — it is what makes the mapping
   mechanical instead of interpretive.
5. **Deliberately not doing** — one line of negative space, naming what the
   story is explicitly not building. This is the handshake with `simplify`:
   an abstraction named here as *not* being built cannot reappear mid-build
   as a surprise.

## The cap — 0 to 6 decisions

**More than 6** means the story already exceeds `decomposition_threshold`
(read live from `governance-protocols`) in structural terms, not just file
count — route it back to re-scope, do not approve it.

**Zero is legitimate and must stay cheap.** Most stories are not
architecturally interesting:

```output
## Design Approach
No new structure — this story extends `TierSettingsForm` and `PATCH
/api/tiers` in place, following the existing form/handler split.
Deliberately not doing: no new module, no new boundary.
```

If zero is not cheap and explicitly approvable, devs write filler on trivial
stories — this is the single most important anti-ceremony feature. A dev is
never asked to invent a decision a story doesn't have.

## Approvable vs rejectable — the gate's own test

**Approvable:** every row names a concrete boundary in this repo (file,
module, layer, call direction); every "Alternative rejected" is a shape
someone could actually have built; every Phases entry references a real
decomposition-table row; count is 0–6.

**Rejectable — send back, one round, same shape as a Gate 0 gap:**

- A Decision that restates an `[AC]` ("returns 400 on invalid input" is an AC,
  not a design decision).
- An Alternative rejected that is "none" or a strawman ("alternative: write it
  badly").
- A Why that is a principle name with no consequence — "SOLID", "clean
  architecture", "separation of concerns", "best practice".
- An abstraction with one caller in the diff, no declared second caller, and
  no test-seam justification — this is `simplify`'s single-caller-inline
  candidate, caught here before it is ever built
  (`simplify/references/candidate-catalog.md`).
- More than 6 rows.

A rejected Design Approach is a **hard stop within Gate 1** — restate it and
resubmit; it does not proceed to the decomposition table's approval until it
clears (`references/gates.md`, Gate 1).

## Persisted with the plan

On approval, the Design Approach is written to `spec_path` as its own
**`## Design Approach`** section, alongside the scope contract and the
decomposition table (`references/gates.md`, Gate 1 · step 7;
`references/execution.md`, "No spec, no code"). Both required — this is the
AC.

## Mid-build amendment — when the design changes mid-build

A design legitimately diverges mid-build sometimes. When it does:

1. **Stop.** Do not keep building against a spec that no longer matches the
   plan.
2. **Restate the five fields** for the changed or added decision(s).
3. **Get the dev's explicit approval** — the same hard-stop discipline as the
   original Gate 1 approval; silence is not approval here either.
4. **Rewrite the spec's `## Design Approach` section** to the amended state.
5. **Post one story comment**, exact header:

   ```
   Design Approach amendment — /implement
   ```

   naming what changed and why, per `write-protocol` (draft → approve → push).

An amendment that adds work **no `[AC]` covers** is not a design amendment —
it is a scope change, and is **refused here and routed to the PM/board**, the
same refusal `implement`'s Gate 0 clarification path uses for an answer that
adds `[AC]`-uncovered scope (`references/clarification.md`).
