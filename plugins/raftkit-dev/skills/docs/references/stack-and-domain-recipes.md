# Stack Selection, Archetype Recipes & Domain Recipes

This reference is the docs skill's stack-architect brain. It merges three
concerns into one file: (1) an archetype decision tree with
requirement-to-archetype mapping and trigger signals, (2) copy-pasteable
bootstrap recipes per archetype, and (3) per-domain mini-recipes layered on
after the archetype is chosen. It closes with "when NOT to use" anti-recipes.

All recommendations are evidence-backed by analysis of six production
reference implementations across B2B SaaS, AI content, voice agents, ERP,
geospatial delivery, and consumer mobile.

## The three archetypes

### Archetype A — Better-T-Stack (BTS)

```
Next.js 16 + React 19 + React Compiler
   + shadcn (base-lyra / @base-ui/react) + Tailwind v4
   + TanStack Query + TanStack Form
oRPC (RPCHandler + OpenAPIHandler on same /api/rpc route)
Drizzle ORM + Postgres (Neon serverless OR postgres-js)
Better Auth (organization, admin, apiKey, bearer, dodopayments, ...)
SST v3 on AWS (S3 + CloudFront + λ + Cron; region per market —
   ap-south-1 when the India-market bundle is selected)
Vercel for Next apps
Upstash QStash + Upstash Workflow + Upstash Redis
ZeptoMail + React Email templates
Dodopayments (India-market bundle) | Stripe (US/EU)
envx-cli with .env.production.gpg
pnpm workspace catalog:
```

### Archetype B — Hasura + Amplify Hybrid

```
Vite SPA (TanStack Router) | Next.js 16 | Expo
   + shadcn + Radix + Tailwind v4 + Apollo Client + Zustand
Hasura GraphQL Engine (Docker + Caddy) — data API
   + Cognito JWT validated against JWKS
   + Hasura Actions → API Gateway → Lambdas
Postgres (Neon | RDS | self-hosted w/ PostGIS)
   + optional Milvus | S3 Vectors
Amplify Gen 2 (Cognito + S3 + CloudFront + Lambdas + Custom CDK)
Dual codegen (Apollo hooks + graphql-request SDK)
```

### Archetype C — Vite SPA (lightweight)

```
Vite + React 19 + TanStack Router + Tailwind v4 + shadcn/ui + Zustand
Backend: existing API | Hono+Bun service | serverless functions
No Better Auth / Hasura unless usage warrants it
```

## Decision framework: requirements → archetype

Run this through during discovery. Each row PULLS toward an archetype. If
signals conflict, call it out and ask the user to prioritise.

| Requirement signal | Pulls toward | Reason |
|---|---|---|
| Greenfield, schema in your head | A | Drizzle migrations cheapest for iteration |
| Schema already designed (DBML, ERD, legacy DB) | B | Hasura auto-generates the API |
| GraphQL subscriptions for primary UI | B | Hasura subscriptions free |
| Multi-tenant via Organizations | A | Better Auth `organization` plugin built for it |
| Multi-tenant via row-level JWT-claim filtering | B | Hasura RLS is its strongest feature |
| Voice / conversational AI primary | A + LiveKit + Mastra/ElevenLabs | Two-server topology fits BTS |
| AI content pipeline w/ multi-step retries | A + Upstash Workflow + AI SDK v6 | Proven content-pipeline reference pattern |
| Mobile-first consumer app | A (mobile-only or hybrid) | Expo + bearer plugin + same oRPC |
| Heavy CRUD ERP w/ rich admin | B | Hasura mutations + Apollo subscriptions |
| Customer-embeddable SDK | A + REST `/v1` + Better Auth apiKey | Proven SDK-product reference pattern |
| GraphQL for integrators | B | Publish Hasura |
| Geospatial primary | B (Postgres + PostGIS) | Neon lacks first-class PostGIS |
| Vector search heavy | B + Milvus | Vector-heavy reference pattern |
| Vector search light | A + S3 Vectors via Mastra | Vector-light reference pattern |
| Subscriptions billing in India (India-market bundle) | A + Better Auth dodopayments plugin | India-market reference pattern |
| Usage-based / credit-metered billing | B + credits-guard middleware | Credit-metered reference pattern |
| Existing AWS-heavy team | B | Amplify keeps AWS-native |
| Bun runtime preferred | A variant (postgres-js + Hono on Bun) | Bun-runtime reference pattern |
| Edge-runtime requirement | A | Hasura needs long-lived connection |
| Docs portal alongside | A + Fumadocs | SDK-product reference pattern |
| Internal tool w/ <20 users | C | A/B both overkill |
| Compliance-heavy w/ PII masking in DB | B + Postgres Anonymizer | Privacy-first reference direction |

## Trigger signals from discovery answers

Concrete phrases in answers → what the skill should do:

| User says… | Skill action |
|---|---|
| "We have a DBML spec already" | Lock to B; jump to the ERP domain recipe below |
| "Live updates on a leaderboard / queue / table" | Recommend B (Hasura subs) or A + Pusher/Ably |
| "Voice / talk to the app" | A + LiveKit + (Gemini Live for single-turn / ElevenLabs+Mastra for multi-turn) |
| "AI writes/generates X" | A + Upstash Workflow + AI SDK v6 + per-phase models (AI content pipeline recipe) |
| "Recruiters / hiring / ranking candidates" | B + Milvus + Vertex AI (document-ranking recipe) |
| "Delivery / driver / route" | B + PostGIS (geospatial recipe) |
| "Family / kids / household / parenting" | Probe age-floor; minors → B + privacy-preserving RLS |
| "Property / rent / tenant management" | A + payments + property-management recipe (India-market bundle if applicable) |
| "Marketplace" / "two-sided" | Probe which side has harder problem; choose by that |
| "Internal tool — fixed list of users" | Archetype C |
| "We're already on Supabase / Firebase" | Honour existing investment; produce docs in that flavour |
| "Admin panel for support" | Two-instance Better Auth + X-Auth-Source header |
| "Bulk operations" / "CSV import" | QStash worker Lambda + signed URL upload + report email |
| "Recurring billing with tiers" | Better Auth dodopayments + subscribedProcedure middleware + trial logic |
| "WhatsApp / SMS to customers" | Meta WhatsApp Cloud API + template approval flow + Twilio fallback |
| "Government ID number / KYC verification" | First-class verification package + issuer cert validation + encryption at rest |
| "Need an SDK customers install" | Published `@org/sdk` + `@org/react` + demo app + Fumadocs |
| "Should work offline" | Probe scope: read-only → TanStack Query + MMKV; write-too → CRDT design |
| "Notifications / reminders" | User-specific timing → EventBridge Scheduler per-row; global daily → SST Cron |

## Decision tree the skill walks (one question at a time)

Narrate each answer. Don't ask all at once — adapt based on prior answers.

```
Q1: Internal tool with <20 fixed users?
  YES → Archetype C. STOP.
  NO  → continue

Q2: Existing schema (DBML, ERD, legacy DB)?
  YES → bias B
  NO  → bias A

Q3: GraphQL subscriptions as first-class UI feature?
  YES → strong B
  NO  → unchanged

Q4: Customer-embeddable SDK or partner integration product?
  YES → strong A (+ REST /v1 + apiKey plugin)
  NO  → unchanged

Q5: Team has Amplify Gen 2 experience?
  YES → make B viable
  NO  → bias A

Q6: Voice / conversational AI primary?
  YES → A + LiveKit + (Gemini Live | ElevenLabs+Mastra). STOP after asking which voice flavour.
  NO  → continue

Q7: Mobile-first?
  YES → A + Expo + Uniwind regardless of backend pick
  NO  → continue

Q8: Resolve A vs B from accumulated bias:
  Bias A → A
  Bias B → B
  Tie    → default A (faster to ship, easier to swap later)

Q9: Add modifiers (multi-select):
  India-market bundle (named option — only when the market calls for it)
    → +Dodopayments +WhatsApp +ZeptoMail +ap-south-1 +envx-cli
  Vector search heavy → +Milvus
  Vector search light → +S3 Vectors via Mastra
  Geospatial → +PostGIS (forces B if Neon was planned)
  AI workflows → +Upstash Workflow + AI SDK v6 + AI Gateway + per-phase models
  Real-time presence → +LiveKit data channels OR Pusher/Ably
  Published SDK → +@org/sdk + @org/react + demo app + Fumadocs

Q10: Confirmation
```

### Example narration after Q10

> Based on your answers — B2B SaaS, no existing schema, India market, no
> realtime subscriptions, customer-embeddable SDK planned, mobile app
> planned, no voice — I'm landing on:
>
> **Archetype A (Better-T-Stack)** with modifiers:
> - Published SDK (`@org/sdk` + `@org/react` + demo + Fumadocs)
> - Expo mobile app
> - India-market bundle (Dodopayments + WhatsApp + ZeptoMail + ap-south-1 + envx-cli)
>
> Reasoning: greenfield + SDK requirement is the strongest signal — REST `/v1`
> with Better Auth `apiKey` is what integrators consume. Mobile is well-served
> by Expo + oRPC client. No real-time means no Hasura tax.
>
> One anti-pattern to flag: **don't expose oRPC routes to integrators** — they
> expect REST. Plan `/api/v1/*` as a separate, intentionally-stable contract
> from day one (versioning + deprecation policy).
>
> Want to go with this, or push back on any of it?

---

# Archetype Recipes (copy-pasteable bootstrap)

Once an archetype is chosen, follow the matching recipe verbatim. Each
recipe lists the bootstrap command, the monorepo skeleton, the catalog
versions, the canonical mounts, and the env-management story.

---

## Recipe A — Better-T-Stack SaaS

### Bootstrap
```bash
pnpm create better-t-stack@latest <project-name>
# Run with --help to see latest flags. As of May 2026 the recommended config:
#   --frontend next                       (or "next,expo" or "next,tanstack-router,expo")
#   --backend self                        (in-monorepo)
#   --api orpc                            (or "none" for SPA-only)
#   --auth better-auth                    (or "none")
#   --db-setup neon                       (or "postgres-js" for Bun)
#   --runtime node                        (or "bun" for Hono/Bun stack)
#   --addons turborepo,husky,prettier,biome,changesets
#   --package-manager pnpm
#   --git
#   --install
```

### Monorepo skeleton
```
apps/
  app/            Next 16 — main product, port 3001
  admin/          Next 16 — separate cookie scope, port 3002
  web/            Next 16 — marketing site
  mobile/         Expo SDK 55 (optional)
  docs/           Fumadocs (optional, for SDK products)
  demo/           Sample SDK consumer (optional)
packages/
  api/            oRPC routers
  auth/           Better Auth + plugins
  db/             Drizzle schema + Neon client
  email/          React Email templates + ZeptoMail sender
  env/            t3-env: /server, /web, /cron, /worker
  cron/           SST Lambda handlers
  workers/        SST Lambda handlers for QStash consumers
  editor/         Plate.js wrapper (if rich-text core)
  sdk/            Published @org/sdk (if SDK product)
  react/          Published @org/react (if SDK product)
  config/         shared tsconfig + eslint
```

### `pnpm-workspace.yaml` catalog
```yaml
packages: [apps/*, packages/*]
nodeLinker: hoisted
catalog:
  next: "16.1.1"
  react: "19.2.4"
  react-dom: "19.2.4"
  better-auth: "1.4.18"
  "@orpc/server": "1.13.4"
  "@orpc/client": "1.13.4"
  "@orpc/openapi": "1.13.4"
  drizzle-orm: "0.45.1"
  drizzle-kit: "0.31.8"
  zod: "4.3.6"
  hono: "4.8.0"
  typescript: "5.7.0"
```

### oRPC + OpenAPI mount
```ts
// apps/app/src/app/api/rpc/[[...rest]]/route.ts
import { RPCHandler } from "@orpc/server/fetch";
import { OpenAPIHandler } from "@orpc/openapi/fetch";
import { OpenAPIReferencePlugin } from "@orpc/openapi/plugins";
import { ZodToJsonSchemaConverter } from "@orpc/zod/zod4";
import { appRouter } from "@my-app/api";

const rpcHandler = new RPCHandler(appRouter, { context: createContext });
const openapiHandler = new OpenAPIHandler(appRouter, {
  context: createContext,
  plugins: [
    new OpenAPIReferencePlugin({
      schemaConverters: [new ZodToJsonSchemaConverter()],
    }),
  ],
});

const handler = async (req: Request) => {
  const rpcResult = await rpcHandler.handle(req);
  if (rpcResult.matched) return rpcResult.response;
  const openapiResult = await openapiHandler.handle(req);
  if (openapiResult.matched) return openapiResult.response;
  return new Response("Not found", { status: 404 });
};

export { handler as GET, handler as POST, handler as PUT, handler as DELETE };
```

### SST config skeleton
```ts
// sst.config.ts
export default $config({
  app(input) {
    return {
      name: "my-app",
      home: "aws",
      providers: {
        aws: { profile: "<your-aws-profile>", region: "<your-region>" },
      },
    };
  },
  async run() {
    const bucket = new sst.aws.Bucket("Media", { access: "cloudfront" });
    new sst.aws.Function("UrlImport", {
      handler: "packages/workers/src/handlers/url-import.handler",
      url: true,
      link: [bucket],
    });
    new sst.aws.Cron("DailyJobs", {
      schedule: "cron(30 18 * * ? *)",  // 00:00 IST (adjust to your market TZ)
      function: "packages/cron/src/handler.main",
    });
  },
});
```

### Env management
```makefile
env-dev:    envx decrypt --env development
env-prod:   envx decrypt --env production
env-encrypt-dev:  envx encrypt --env development
env-encrypt-prod: envx encrypt --env production
```
Commit `.env.development.gpg` and `.env.production.gpg`. Never commit
decrypted versions.

### Better Auth two-instance pattern (admin separation)
```ts
// packages/auth/src/index.ts
export const auth = betterAuth({
  database: drizzleAdapter(db, { provider: "pg" }),
  plugins: [organization(), apiKey(), dodopayments({...})],
  advanced: { cookiePrefix: "myapp" },
});

export const adminAuth = betterAuth({
  database: drizzleAdapter(db, { provider: "pg" }),
  plugins: [admin()],
  advanced: { cookiePrefix: "myapp-admin" },
});
```
Server route handler chooses instance via `X-Auth-Source: admin|app` header.

---

## Recipe B — Hasura + Amplify Hybrid

### Bootstrap (stepwise — no single CLI)

1. `mkdir <project> && cd <project> && pnpm init && pnpm-workspace.yaml`
2. `cd apps && pnpm create vite@latest platform -- --template react-ts`
3. `cd packages/backend && pnpm dlx ampx init`
4. `mkdir docker/local services/hasura services/postgres`
5. Write `docker/local/docker-compose.yml` (Postgres + Hasura + Caddy)
6. Wire `codegen.ts` with dual targets
7. `cd packages/backend && pnpm ampx sandbox --identifier <project>`

### Monorepo skeleton
```
apps/
  platform/       Vite SPA — the authenticated product
  website/        Next 15 — marketing/blog/pricing
  admin/          Vite SPA — internal admin (optional)
  mobile/         Expo (optional)
packages/
  backend/        Amplify Gen 2 backend + 30-80 Lambdas
  agent-tools/    Mastra tools (if voice agent)
  agent-memory/   Mastra Memory wrapper (if voice)
  api-client/     Shared Apollo factory
  hasura-sdk/     graphql-request SDK for Lambdas
  ui/             shadcn + Radix + generated GraphQL hooks
  email/          React Email
  validators/     Zod schemas
  env/            t3-env
  shared/         cross-cutting utils
libs/
  backend/        Lambda-side helpers (hasura-service, milvus, etc.)
services/
  hasura/         Migrations + metadata YAML
  postgres/       Dockerfile (PostGIS if needed)
docker/
  local/          docker-compose.yml (Postgres + Hasura)
  production/     docker-compose.yml (+ Caddy TLS termination)
```

### Codegen dual-target
```ts
// codegen.ts
const config: CodegenConfig = {
  schema: [{ "https://hasura.example.com/v1/graphql": {
    headers: { "x-hasura-admin-secret": process.env.HASURA_GRAPHQL_ADMIN_SECRET! },
  }}],
  documents: [
    "apps/platform/src/**/*.graphql",
    "packages/backend/amplify/functions/**/*.graphql",
  ],
  generates: {
    "packages/ui/src/graphql/base-types.ts": { plugins: ["typescript"] },
    "packages/ui/src/": {
      preset: "near-operation-file-preset",
      presetConfig: { extension: ".generated.ts", baseTypesPath: "graphql/base-types.ts" },
      plugins: ["typescript-operations", "typescript-react-apollo"],
    },
    "packages/hasura-sdk/src/": {
      preset: "near-operation-file-preset",
      presetConfig: { extension: ".sdk.ts", baseTypesPath: "graphql/base-types.ts" },
      plugins: ["typescript-operations", "typescript-graphql-request"],
      config: { documentMode: "string" },
    },
  },
  config: {
    scalars: { uuid: "string", numeric: "number", jsonb: "Record<string, unknown>" },
  },
};
```

### Amplify backend.ts skeleton
```ts
// packages/backend/amplify/backend.ts
const backend = defineBackend({
  auth,
  data,
  storage,
  createAdmin,
  inviteUser,
  addOrder,
  ...
});

// Add custom CDK stacks
const sqsStack = backend.createStack("SqsQueueStack");
const queue = new sqs.Queue(sqsStack, "MainQueue", {
  visibilityTimeout: Duration.minutes(5),
  deadLetterQueue: { maxReceiveCount: 10, queue: dlq },
});

// Storage triggers
storage.resources.bucket.addObjectCreatedNotification(
  new s3n.LambdaDestination(onUploadFn),
);
```

### Hasura Actions pattern
Lambdas exposed as Hasura Actions via API Gateway HTTP API, wired per
module.

---

## Recipe C — Lightweight (Vite SPA / shadcn-init)

### Bootstrap
```bash
pnpm create vite@latest <project> -- --template react-ts
cd <project>
pnpm install
pnpm dlx shadcn@latest init                # shadcn baseline
pnpm add @tanstack/react-router @tanstack/react-query \
  tailwindcss @tailwindcss/vite zustand class-variance-authority \
  lucide-react sonner
```

### Skeleton
```
src/
  main.tsx
  routes/                                  # if using TanStack Router file-based
  components/ui/                           # shadcn components
  components/                              # custom components
  lib/
  stores/                                  # zustand stores
  hooks/
public/
index.html
vite.config.ts
tailwind.config.ts (or @tailwindcss/vite plugin)
tsconfig.json
```

### When to add backend
Start with no backend. If user later needs one:
- Lightweight CRUD → add a Hono+Bun service in same repo
- Heavier → graduate to Archetype A (BTS)

---

## Common to all archetypes

### Husky + commitlint + cz-customizable + release-it
```bash
pnpm dlx husky init
pnpm add -D @commitlint/cli @commitlint/config-conventional cz-customizable release-it
```

### Sentry wiring
```bash
pnpm add @sentry/nextjs        # or @sentry/expo, @sentry/node
pnpm dlx @sentry/wizard@latest -i nextjs
```

### Direnv + envx
```bash
brew install direnv envx       # or curl install per platform
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
cat > .envrc << 'EOF'
dotenv .env.development
EOF
direnv allow
```

---

# Domain Recipes

Per-domain mini-recipes. Use after archetype is chosen to layer on
domain-specific modifiers. Each recipe = Pick / Why / Don't.

---

## India-Market B2B SaaS (one named regional option — apply only when the market calls for it)

**Pick:** Archetype A. Next 16 + oRPC + Drizzle + Neon + Better Auth
(`organization`, `admin`, `apiKey`, `dodopayments`) + SST (ap-south-1) +
Vercel + Upstash + ZeptoMail + WhatsApp Cloud API + envx-cli.

**Why:** India payment rails (Dodopayments), India-friendly latency
(ap-south-1), India comms (WhatsApp templates) all have plug-and-play
integrations. Better Auth `organization` + `subscribedProcedure` middleware
gives trial-or-subscription gating in one file.

**Don't:** Don't pick Stripe (worse INR experience), don't pick Cognito
(you don't need it; Cognito IAM wastes a week), don't go Hasura unless
schema is already DBML.

---

## AI Content Pipeline

**Pick:** Archetype A + **Upstash Workflow** + **AI SDK v6 + AI Gateway** +
**per-phase model selection** + **Plate.js as workspace package** (only if
rich-text editor is core) + **Published SDK** for partner consumption.

**Why:** Multi-step LLM jobs need durable orchestration (Workflow),
provider-agnostic model selection (Gateway), and per-phase quality vs cost
tuning (different model per step). Plate.js as its own package isolates
~40 plugins from the dashboard build.

**Don't:** Don't build orchestration in-app — Workflow gives retries,
checkpoints, observability for free. Don't hard-code a single LLM
provider — AI Gateway saves you when one is down.

---

## AI Voice Agent

**Pick:** Archetype A + **LiveKit (self-hosted SFU in-region for
latency-sensitive markets, Cloud elsewhere)** + one of:

- **Single-turn voice + tools → Gemini 2.5 Live.** Native audio, ~70
  languages, search grounding, fastest TTFB.
- **Multi-turn conversational + memory + tools → ElevenLabs Conversational
  AI + Mastra Memory + per-tool Lambdas.** Better persona control, "Custom
  LLM" seam for privacy.

**Architecture:** Two-server topology — persistent CRUD server
(Hono/Bun on Railway) + persistent voice worker (LiveKit Agents Worker on
Lightsail/Fly) — **never combine them**. Voice token minted by CRUD server
with `RoomAgentDispatch` metadata.

**Don't:** Don't run voice on Vercel (cold starts kill turn-taking).
Don't pick a generic WebRTC SDK (LiveKit is the only one with first-class
server agents). Don't store raw transcripts without PII masking.

---

## Mobile-First Consumer App

**Pick:** Expo SDK 55 + **Uniwind 1.6 + Tailwind v4** (newer; replaces
NativeWind) + Zustand + TanStack Query (persisted via MMKV) + Apollo or
oRPC client + **direct FCM + APNs via `firebase-admin`** (skip Expo Push) +
EAS Build + Changesets for releases.

**Why:** Hermes is mature; Tailwind via Uniwind is the cleanest RN styling
story; MMKV-backed TanStack Query persistence gives offline reads for free;
direct FCM avoids the Expo Push proxy when you outgrow the free tier.

**Don't:** Don't use Expo Push at scale, don't pick NativeWind for new
projects (Uniwind is the successor), don't use `Intl` for timezone math on
Android (broken in Hermes — use spacetime).

---

## Internal Admin / Lightweight SPA

**Pick:** Archetype C — Vite + React 19 + TanStack Router + Tailwind v4 +
shadcn/ui + Zustand. Backend: consume existing API OR pair with a single
Hono/Bun service.

**Why:** You don't need Next.js for an internal tool with fixed users.
SPA is faster to ship and debug.

**Don't:** Don't add Better Auth if you have <10 users — start with a shared
password or your SSO provider's OIDC.

---

## ERP / Heavy CRUD with Subscriptions UI

**Pick:** Archetype B. Vite + TanStack Router (admin) + Apollo Client +
GraphQL-WS subscriptions + Hasura (Docker, Caddy) + Postgres (PostGIS if
geo) + Cognito via Amplify Gen 2 + custom HTTP API Gateway for Hasura
Actions → Lambdas + dual codegen (Apollo hooks + graphql-request SDK).

**Why:** ERP entities are highly relational, change shape often, benefit
from auto-generated GraphQL. Subscriptions give ops teams live updates
without polling. Hasura permissions + Cognito JWT claims = cleanest RBAC.

**Don't:** Don't expose Hasura admin secret in Lambda envs (use Secrets
Manager). Don't put business logic in Hasura computed fields — escape to
Lambda via Actions. Don't skip dual codegen — manual SDKs always drift.

---

## AI SaaS — Document Upload + Ranking

**Pick:** Archetype B + **Milvus** (Zilliz) + **Vertex AI primary, Bedrock
fallback** + **SQS + custom Lambda router** + subscription billing (via the
regional payment provider) + **credits-guard middleware** on every AI call +
**5 OAuth integrations** (Google/Microsoft/Zoho/SMTP/GitHub) using the same
connect/callback/disconnect Lambda triplet.

**Why:** Document extraction + ranking needs heavy vector search; Milvus's
RRF reranking on dense+sparse is the right tool. Vertex AI gives best
price/perf on Gemini; Bedrock is your fallback for IAM-consolidated
workloads.

**Don't:** Don't try DynamoDB for the relational core (one reference
implementation moved off it — Postgres+Hasura is the answer). Don't gate AI
calls in the UI — always gate in Lambda via credits-guard.

---

## Marketplace / Two-Sided Platform

**Pick:** Default Archetype A unless schema is already designed (then B).
Add: **separate apps for each side** (`apps/buyer`, `apps/seller`),
**separate Better Auth instances** if sides have very different auth
requirements, **transactional outbox pattern** for cross-side notifications,
**Stripe Connect or Razorpay Route** for payouts.

**Don't:** Don't share a single dashboard between sides — they evolve
differently. Don't model "user is buyer OR seller" — model "user has
buyer_profile and/or seller_profile" so a user can be both.

---

## Multi-Tenant B2B with Org-Switcher

**Pick:** Archetype A. Better Auth `organization` plugin. Every API
procedure reads `activeOrganizationId` from session and scopes queries.
Add an org-switcher UI calling `setActiveOrganization`. Use `admin` plugin
for platform access (separate cookie scope via X-Auth-Source header).

**Don't:** Don't roll your own org model — Better Auth's is battle-tested.
Don't pass orgId in URLs as primary scope — JWT claim is safer.

---

## Property / Rental Management

**Pick:** Archetype A + **government ID QR verification package** (KYC) +
payments (regional provider) + **WhatsApp template messages** (if the
market uses them) + **SST Cron** (single 5-job Lambda for rent generation,
mark-overdue, late-fees, reminders, alerts) + **PWA** (`next-pwa`) +
**6-permission warden RBAC**.

**Don't:** Don't store the raw government ID number — encrypt at rest, only
persist the last 4 digits unmasked. Don't try to handle KYC photo without a
JPEG2000 decoder.

---

## Delivery / Geospatial

**Pick:** Archetype B + **Custom Postgres image with PostGIS** + **areas /
addresses / locations tables with geometry columns** + **delivery-agent PWA**
with offline-first QR scanner.

**Don't:** Don't pick Neon serverless (PostGIS not first-class). Don't
skip area-grouping at the schema level — it ripples into every list query.

---

# "When NOT to use" — anti-recipes

### Don't pick Archetype A (BTS) when…
- DBML-first schema that changes often → use B
- Need GraphQL subscriptions as primary UI → use B
- Team has deep AWS-native expertise / wants Amplify ecosystem → use B
- Hundreds of complex JWT-claim-driven row rules → Hasura's RLS is better
- Need PostGIS primary
- Internal tool with <10 users → use C

### Don't pick Archetype B (Hasura+Amplify) when…
- Iterating schema weekly in a new product → Drizzle is faster
- Edge-runtime API responses needed → Hasura requires long-lived connection
- Publishing SDK to customers → REST is what integrators want, not GraphQL
- Solo dev / small team without prior Amplify experience → CFN nested-stack
  debugging eats weeks
- Business logic is mostly in resolvers (not in CRUD) → escape-to-Lambda
  pattern slower than oRPC
- Deeply customised auth (impersonation, multi-instance, custom session shapes)
  → Better Auth more flexible than Cognito

### Don't pick Archetype C (Vite SPA) when…
- Need SEO → Next.js
- Public marketing site → Next.js
- PWA with offline writes → can be done but Next + next-pwa more standard

### Don't pick LiveKit Cloud when…
- Primary market is latency-sensitive and far from LiveKit Cloud regions →
  self-host the SFU in-region (e.g. Mumbai for an India-primary product)

### Don't pick Mastra when…
- Only single-turn LLM calls → AI SDK v6 alone is simpler
- Don't need agent memory → Mastra's value is the Memory primitive

### Don't pick Dodopayments when…
- US-only / EU-only → Stripe more mature outside India

### Don't pick Expo Push when…
- >10k DAU receiving pushes → direct FCM/APNs via firebase-admin scales better
