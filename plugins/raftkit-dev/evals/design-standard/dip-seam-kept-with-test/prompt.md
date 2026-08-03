The diff adds this domain function, plus a unit test in the same diff that
calls `resolveTier` directly with an in-memory fake, asserting tier math with
no database involved:

```ts
export function resolveTier(order: Order, getTiers: () => Promise<Tier[]>) {
  // ...pure tier calculation using order and the tiers returned by getTiers...
}
```

`simplify` proposes inlining the `getTiers` parameter into a direct database
call inside `resolveTier`, since there's only one caller. Review that proposal.
