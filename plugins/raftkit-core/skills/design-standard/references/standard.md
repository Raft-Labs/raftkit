## RAFTLABS MODULE DESIGN STANDARD (MDS)

These are **project rules**. A violation of a rule in this section is an
explicit CLAUDE.md violation, not a stylistic preference. Ten rules, each with
the diff-visible trigger that fires it and the fix that clears it. They govern
React/Next.js, Node.js, and AWS Serverless code in this repository.

Read the **Precedence** section at the end before acting on any finding. This
standard never asks for an abstraction that serves exactly one concrete case.

### MDS-1 — One reason to change per file
A file exports one cohesive concern. A component may not do data access,
business decisions, and presentation at once; a Node function may not do
transport parsing, business decisions, and persistence at once.
**Trigger:** one exported function or component whose body both performs I/O
(`fetch`, `await db.*`, a Drizzle/Prisma query, an `@aws-sdk` client `.send()`,
`axios`) **and** contains two or more domain conditionals.
**Fix:** move the decision into a named pure function in the same module. This
is a move, not a new layer.

### MDS-2 — Handlers are thin adapters
Every Lambda handler, Next.js Route Handler, Server Action, and API route is:
validate input → call **one** domain function → map the result to a response.
No business branching, no SQL/DDB/S3 calls, no multi-step orchestration in a
handler body. Target ≤25 lines excluding imports and types.
**Trigger:** a handler body over 25 lines; a handler containing a datastore or
AWS SDK call; a handler `try/catch` wrapping more than one domain call.
**Fix:** move the body to `<module>/<use-case>.ts` exporting one function; the
handler calls it. The domain function must be unit-testable without the
runtime — that is the point of the rule.

### MDS-3 — Depend on the narrowest type you use
A parameter types only the fields the body reads. Never accept a whole entity,
`Session`, `Request`, or `APIGatewayProxyEvent` to read two fields; never pass
the raw event deeper than the handler; never spread a full domain row into a
presentational component.
**Trigger:** a new function whose parameter is an entity/event/request/session
type but whose body references three or fewer of its fields.
**Fix:** narrow to an inline structural type or `Pick<>`. This removes surface.

### MDS-4 — No new inheritance; compose
Do not introduce `abstract class` or `class X extends Y` where `Y` is
app-owned. Framework base classes you are required to extend (`Error`, SST/CDK
constructs) are exempt, one level only.
**Trigger:** a new `abstract class`; a new app-owned `extends`; a `super.*()`
override that changes the parent's contract.
**Fix:** extract the shared behaviour as a function or hook both call. This
removes a layer.

### MDS-5 — A shared contract every member can honour
Every member of a shared interface or discriminated union honours the declared
contract without narrowing it: no `not implemented` throws, no returning
`null` where the contract says non-null, no method half the implementations
lack. If one variant cannot honour the contract, the contract is wrong — split
the type.
**Trigger:** `throw new Error('not implemented' | 'unsupported')` inside an
implementation; an optional method present on some implementations only; call
sites that must `instanceof`/re-narrow a "shared" type to use it correctly.
**Fix:** split into two honest types, or move the odd operation off the shared
surface.

### MDS-6 — Extend by data, not by editing a dispatch — above the threshold only
When a `switch`/`if-else` on a domain discriminant (status, role, tier,
provider, event type) reaches **three or more branches** **and** the same
discriminant is switched on in **two or more files**, collapse it to one
exhaustive `Record<Enum, …>` lookup in one file, with an `assertNever`
exhaustiveness guard. **Below that threshold, leave the `if/else` alone** — a
registry for two cases is over-engineering and will be removed.
**Trigger:** the same enum switched in ≥2 files with ≥3 branches each; or a new
enum member added with no compile error anywhere (no exhaustiveness guard).
**Fix:** one lookup map plus `assertNever`.

### MDS-7 — Invert only at I/O boundaries, and only with a parameter
Domain and use-case functions do not import infrastructure: no `@aws-sdk/*`, db
client, `fetch`, Stripe/Twilio/ZeptoMail SDK, or `process.env` below the
composition root. They receive what they need as **arguments** — a value, or a
narrow function-typed parameter such as `(id: string) => Promise<Order | null>`.
Wiring happens at the composition root: the handler, the route, the Server
Component, `main`.
**Never introduce an `interface`, `abstract class`, factory, provider, or DI
container to satisfy this rule.** A single-implementation `IOrderRepository` is
not a design win; it is a removal candidate and this standard does not defend
it.
**Trigger:** an infrastructure import inside a domain/use-case path;
`process.env.X` read below the composition root; a unit test that must
`vi.mock`/`jest.mock` a module to exercise a business rule.
**Fix:** pass the dependency as a parameter.

### MDS-8 — Module boundaries are one-way and explicit
Each module (`modules/<name>/`, `packages/<name>/`, `services/<name>/`) exposes
one public entry (`index.ts`). Cross-module imports use only that entry. No deep
imports into another module's internals, no import cycles, no UI file importing
another module's persistence layer.
**Trigger:** a new import path containing another module's internal segment
(`../orders/db/…`, `@app/orders/src/internal/…`); a new cycle between modules;
an `app/`/`pages/` file importing a `db`/`schema`/`repository` file directly.
**Fix:** export it from that module's `index.ts`, or move the caller.

### MDS-9 — Shared state and effects are not a design pattern (React + Lambda)
No new React context, global store slice, or module-level mutable singleton for
state only one route subtree reads. Server-owned data is fetched on the server —
not mirrored into client state. `useEffect` may not derive state from props or
fetch data the server can provide. In a Lambda module, module-scope mutable
state that carries per-request data is a correctness bug under warm reuse.
**Trigger:** a new `createContext` whose provider wraps a single route; a
`useEffect` whose body only calls `setState` from props; a `useEffect` + `fetch`
pair in a component that could be a Server Component; a module-scope `let` or
mutable object in a handler file assigned per request.
**Fix:** derive during render; fetch on the server; pass props; keep per-request
state inside the handler invocation.

### MDS-10 — Duplication is a defect only when the copies must change together
Extract on the **third** occurrence — or on the second when both copies encode
the same business rule (a price, a tax rule, a permission check, a status
transition, a timezone rule). Two coincidentally similar blocks in different
modules stay duplicated. Never extract across a module boundary (MDS-8) merely
to remove repetition: duplicate rather than couple two modules.
**Trigger:** a third literal-identical block of ≥8 lines; the same business
constant, threshold, or permission string appearing in two or more files.
**Fix:** one named function or constant in the owning module.

### Precedence — when the minimalism pass and this standard disagree
The minimalism pass (`raftkit-dev/simplify`) removes abstractions that serve
exactly one concrete case. It is the default winner. This standard is written so
the two almost never meet:

1. Every rule above is a **move**, a **deletion**, or a **narrowing**, or it is
   gated behind a **plural trigger** — MDS-6 needs ≥3 branches in ≥2 files,
   MDS-10 needs the third occurrence (or the same business rule twice), MDS-7
   permits only a parameter and explicitly forbids an interface or factory. None
   of them produces a single-caller abstraction.
2. If the minimalism pass proposes inlining something and an MDS rule appears to
   defend it: **name the rule and its met trigger, or the abstraction goes.**
   No met trigger ⇒ **simplify wins** and the code is inlined.
3. One exception survives an unmet trigger: an **MDS-7 boundary seam that exists
   so a domain rule can be unit-tested without I/O**. It is kept only if a test
   in the same diff actually exercises it. **No test, no seam.**
4. The order is fixed: **simplify runs first; the design review runs on the
   post-simplify diff.** A design finding never re-adds what simplify removed
   unless clause 3 applies — and then it arrives together with its test.
