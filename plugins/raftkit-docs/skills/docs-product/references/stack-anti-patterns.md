# Stack Anti-Patterns (steer the developer away)

The implementation-stack half of the proactive scan. The product-level trigger
catalogue lives in `raftkit-core/discovery-interview` →
`references/proactive-prompts.md`; this table is the part that only makes sense
once an archetype is on the table, so it stays here with the rest of the stack
opinion (`stack-and-domain-recipes.md`).

Scan every developer answer against both. When a row below fires, say so before
moving on.

| If user proposes… | Skill pushes back with… |
|---|---|
| Storing raw passwords | "Better Auth handles hashing — never store raw" |
| Storing an API key your own server issues | "Hash it at rest and show it once — you only ever compare it, never read it back" |
| Hashing a third-party credential the app has to send later | "That one has to be readable again — encrypt it or keep it in a secrets manager, never hash it" |
| Using `db:push` for migrations | "Always generate migrations + drizzle-kit migrate" |
| Single Vercel project switching via `.vercel/<app>.project.json` swap | "Use one Vercel project per app — swap pattern is fragile" |
| Custom Upstash REST client | "@upstash/redis + @upstash/ratelimit handle this — avoid reinventing" |
| Environment variables totalling > 4 KB | "Lambda's 4 KB limit is the combined total across all env vars, not per variable — use SST Secret or Secrets Manager" |
| Sentry only on backend | "Wire @sentry/nextjs and @sentry/expo from day 1 — backfill is painful" |
| Permission table duplicated in router | "Import from packages/auth — duplicates drift" |
| Drizzle in a Hasura+Amplify project | "Hasura already owns data access and migrations — Drizzle duplicates both" |
| Expo Push at scale | "Direct FCM + APNs via firebase-admin scales better past ~10k DAU receivers" |
| Stripe for a single-region product where a local provider fits better (e.g. India-only) | "A local-market provider (e.g. Dodopayments for INR) can have a better regional experience + Better Auth plugin" |
| NativeWind for new Expo project | "House default is Uniwind — a separate project, not a NativeWind upgrade path. NativeWind stays a valid pick, especially on an existing codebase" |
| Cognito for greenfield BTS project | "Better Auth more flexible and matches the rest of the stack" |
