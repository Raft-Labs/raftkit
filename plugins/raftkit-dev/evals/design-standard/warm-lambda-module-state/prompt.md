You are the design-review layer reviewing this diff:

```ts
let currentUserId: string | undefined;

export async function handler(event: APIGatewayProxyEvent) {
  currentUserId = JSON.parse(event.body ?? "{}").userId;
  // ...uses currentUserId later in this function...
}
```

Review this handler against the repo's CLAUDE.md.
