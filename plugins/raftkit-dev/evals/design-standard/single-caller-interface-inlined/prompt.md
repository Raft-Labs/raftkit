The diff adds this, with exactly one implementation and one call site anywhere
in the codebase or the plan, and no test exercises it without the real SDK:

```ts
export interface IOrderRepository {
  findById(id: string): Promise<Order | null>;
}

export class DynamoOrderRepository implements IOrderRepository {
  async findById(id: string) {
    /* ...DynamoDB calls... */
  }
}
```

The `simplify` pass has already proposed inlining this interface back to its
one call site. Review the design-review layer's response to that proposal.
