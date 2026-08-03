The diff adds this new function:

```ts
function greetingFor(session: Session): string {
  return `Hello, ${session.user.firstName}!`;
}
```

`Session` is a large type with dozens of fields (tokens, roles, expiry,
device info, etc.); this function reads exactly one of them.

Review this function against the repo's CLAUDE.md.
