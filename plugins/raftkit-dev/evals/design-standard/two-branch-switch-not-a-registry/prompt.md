---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are the design-review layer reviewing this diff, the only place in the
codebase that branches on order status:

```ts
function label(status: "pending" | "paid"): string {
  if (status === "pending") return "Awaiting payment";
  return "Paid";
}
```

Review this function against the repo's CLAUDE.md.
