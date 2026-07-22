---
name: hasura
description: Use when working on a project's Hasura schema — phrases like "create a new migration", "add a hasura table", "add an enum table", "scaffold a hasura migration", "query the dev hasura endpoint", "check migration status", "rollback a hasura migration", "add hasura permissions". Scaffolds race-safe timestamped migration folders with uuid defaults + updated_at triggers + opinionated permissions YAML; runs ad-hoc GraphQL against any stage; wraps the project's Make targets so commands stay consistent. Refreshes the schema snapshot before and after every DDL change. Never edits applied migrations.
---

# Hasura development skill

This skill owns the Hasura development loop in a project: scaffolding
migrations, authoring metadata YAML, applying via the project's Make targets,
refreshing the schema snapshot, and running ad-hoc GraphQL against any stage.

## Discover the project's conventions first — never assume them

Every path, stage name, port, and naming pattern below is a **convention
discovered from the repository or the Project Profile**, not a constant of
this skill. Before doing anything, establish:

- **`<hasura-root>`** — the Hasura project directory: locate `config.yaml`
  (the Hasura CLI config) plus sibling `migrations/` and `metadata/`
  directories. Example: `services/hasura`.
- **`<schema-snapshot>`** — the committed schema snapshot the project keeps
  honest (DBML, SQL dump, or similar) and the Make target that refreshes it.
  Example: `docs/schema.dbml` via `make create-dbml`.
- **Make targets and stage names** — read the Makefile. Targets like
  `hasura-migrate`, `hasura-migrate-status`, `hasura-env`, `hasura-export`
  and stages like `local` / `development` / `production` are examples of one
  project's naming; use whatever this repo actually defines.
- **Env-file location** — where per-stage Hasura env files live and how they
  are decrypted. Example: `<hasura-root>/console/.env.<stage>`,
  gpg-encrypted, decrypted via `make hasura-env stage=<stage>`.
- **Database name** — from `metadata/databases/`; `default` is the common
  example.
- **Roles** — from existing permission YAML. `user` / `service` /
  `anonymous` (with `admin` implicit) is a typical set; discover the real
  one.
- **Tenancy model** — the tenant column/relationship (e.g. an `org_id`,
  `team_id`, or `family_id` FK) that scopes user-visible rows. Discover it
  from existing tables and permission filters; never assume one.
- **Secret env var names** — from the env files and metadata. Examples:
  `ACTION_BASE_URL`, `HASURA_GRAPHQL_ADMIN_SECRET`,
  `HASURA_EVENT_TRIGGER_SECRET`, header `x-hasura-event-secret`.
- **Webhook path convention** — from existing event triggers. Example:
  `/internal/<path>` on the actions base URL.
- **Deploy remotes / branch model** — from the Project Profile or git
  config. Some projects have a deploy remote that accepts only one ref;
  never push feature branches to such a remote.

Paths written as `<hasura-root>`, `<schema-snapshot>`, `<stage>` below mean
"the discovered value". Concrete paths appear only as clearly-marked
examples.

## Quick reference

Commands below use one project's Make-target names as examples — substitute
the discovered equivalents.

| Action | Command (example naming) |
|---|---|
| Create a table | `.claude/skills/hasura/scripts/new-migration.sh create-table <name> --col "<spec>" ...` |
| Create an enum | `.claude/skills/hasura/scripts/new-migration.sh create-enum-table <name> --values "a,b,c"` |
| Add a column | `.claude/skills/hasura/scripts/new-migration.sh add-column <table> <col> <type> [...]` |
| Drop a column | `.claude/skills/hasura/scripts/new-migration.sh drop-column <table> <col>` |
| Add an index | `.claude/skills/hasura/scripts/new-migration.sh add-index <table> <cols> [--unique] [--partial "<where>"]` |
| Rename | `.claude/skills/hasura/scripts/new-migration.sh rename column\|table <from> <to> [--table <t>]` |
| Function/trigger scaffold | `.claude/skills/hasura/scripts/new-migration.sh function-trigger <slug>` |
| Permission-only change | `.claude/skills/hasura/scripts/new-migration.sh permission-only <slug>` |
| Empty migration shell (hand-rolled SQL) | `make hasura-migrate-create stage=local name=<slug>` |
| Refresh schema snapshot | `make create-dbml` (or the project's snapshot script) |
| Apply migrations | `make hasura-migrate stage=local` |
| Migration status | `make hasura-migrate-status stage=<stage>` |
| Roll back one | `make hasura-migrate-delete stage=local version=<13-digit-ts>` |
| Reapply one | `make hasura-migrate-reapply stage=local version=<13-digit-ts>` |
| Export metadata after console edits | `make hasura-export stage=local` |
| Query a stage | `.claude/skills/hasura/scripts/hasura-query.sh --stage=<s> [--role=user --user-id=<uuid>] <file>` |

**Choosing a creation path:**
- **Typed scaffolders** (`new-migration.sh create-table`, `add-column`,
  etc.) — the default. They generate `up.sql`/`down.sql` **and** the
  permission YAML, run collision checks against `<schema-snapshot>`, and
  pick a race-safe timestamp (`max(now_ms, latest_ts + 1)`).
- **The migrate-create Make target** — wraps the official
  [`hasura migrate create`](https://hasura.io/docs/2.0/hasura-cli/commands/hasura_migrate_create)
  CLI (`--project <hasura-root> --database-name <db>`). Use it for
  migrations the scaffolders don't cover: bespoke SQL (DML backfills,
  multi-statement DDL, function/view bodies that don't fit the templates),
  introspection-based migrations (`--from-server`), or when you want an
  **empty `up.sql`/`down.sql` shell** to fill by hand. Requires the stage's
  env file to have been decrypted once (example: `make hasura-env
  stage=local` so `<hasura-root>/console/.env.local` exists).
  **Permissions YAML is NOT generated** — author it by hand under
  `<hasura-root>/metadata/databases/<db>/tables/`.

## Column SPEC format

`name:type[:not_null][:default=<expr>][:fk=<table>.<col>]`

Examples:
- `title:text:not_null`
- `score:int:default=0`
- `<tenant>_id:uuid:not_null:fk=<tenant-table>.id` (e.g. `org_id:uuid:not_null:fk=orgs.id`)
- `status:text:not_null:default='draft':fk=event_status.value`

## Critical rules

1. **Never edit a migration that has been applied.** Create a new dated
   migration that corrects the issue.
2. **Always apply migrations via the project's apply target** (example:
   `make hasura-migrate stage=...`) — never invoke `hasura migrate apply`
   directly. (For *creating* migrations, both the typed scaffolders and the
   migrate-create Make target are fine; the latter is a thin wrapper around
   `hasura migrate create`.)
3. **Never migrate dev or production directly.** Only `stage=local`.
   Dev/staging/prod go through the deploy pipeline.
4. **Always refresh the schema snapshot before and after DDL.** Pre =
   collision check, post = keep `<schema-snapshot>` honest.
5. **Migration files, metadata YAML, and the refreshed schema snapshot
   commit together.** One atomic commit per schema change.
6. **Admin role permissions are forbidden in YAML.** Admin has implicit full
   access; declared admin blocks corrupt audits.
7. **Confirm before destructive ops** — drop-column, rename,
   hasura-migrate-delete, hasura-migrate-reapply. The scaffolder asks;
   honour the answer.
8. **Never push protected branches without per-action approval.** Follow
   the project's branch/push policy from its Project Profile or memory.
9. **Respect single-ref deploy remotes.** If the project has a deploy
   remote that accepts only one designated ref, never push feature branches
   there — discover this from the Project Profile or git config.
10. **Admin secret never echoes to stdout/stderr.** `hasura-query.sh`
    passes it only via `curl -H`; do not log env files. Redact if it ever
    appears in output.

## Workflows

### A. Create a new tenant-scoped table

Use the project's discovered tenant column (example below uses `org_id` →
`orgs.id`; substitute the real one):

```bash
.claude/skills/hasura/scripts/new-migration.sh create-table meal_plans \
    --col "org_id:uuid:not_null:fk=orgs.id" \
    --col "title:text:not_null" \
    --col "scheduled_for:timestamptz"
```

The scaffolder will:
1. Refresh the schema snapshot and check `<schema-snapshot>` for collisions.
2. Compute a race-safe timestamp.
3. Render `up.sql`, `down.sql`, and `public_meal_plans.yaml` from templates.
4. Print all three for review and ask "Write these files?".
5. On confirmation: write the migration folder + metadata YAML; print
   follow-up instructions.

Then (example paths):
```bash
make hasura-migrate stage=local
make create-dbml
git add <hasura-root>/migrations/<db>/<ts>_create_meal_plans/ \
        <hasura-root>/metadata/databases/<db>/tables/public_meal_plans.yaml \
        <schema-snapshot>
git commit -m "feat(hasura): add meal_plans table"
```

### B. Create an enum table

```bash
.claude/skills/hasura/scripts/new-migration.sh create-enum-table event_status \
    --values "draft,published,cancelled,archived"
```

### C. Add a column to an existing table

```bash
.claude/skills/hasura/scripts/new-migration.sh add-column meal_plans notes text
```

The scaffolder refreshes the snapshot, verifies the table exists and the
column doesn't, then writes the ALTER. **You must hand-edit
`public_meal_plans.yaml`** to add the new column to the relevant permission
column lists.

### D. Query a non-local stage as a specific user

Stage names are the project's own (example: `development`):

```bash
make hasura-env stage=development        # one-time per session: decrypt env

.claude/skills/hasura/scripts/hasura-query.sh \
    --stage=development \
    --role=user \
    --user-id=00000000-0000-0000-0000-000000000001 \
    queries/my-debug.graphql
```

Pass `--role=admin` (default) to bypass row-level perms entirely. Use
`--variables='{...}'` for parameterised queries.

### E. Inspect migration status / roll back

```bash
make hasura-migrate-status  stage=local
make hasura-migrate-delete  stage=local version=<13-digit-ts>
make hasura-migrate-reapply stage=local version=<13-digit-ts>
```

### F. Console-driven schema work (advanced)

If you author schema in the Hasura console UI (e.g., complex permissions,
computed fields), export back to metadata afterwards:

```bash
make hasura-console stage=local       # opens the console
# ...make changes in the UI...
make hasura-export  stage=local       # writes changes back to <hasura-root>/metadata
```

> ⚠️ `hasura metadata export` (and any console save that triggers it)
> **strips all YAML comments** and reorders keys/lists. It does **not**
> drop real metadata — only comments, ordering, and empty
> `configuration: {}` blocks. If inline `#` context matters, keep it in
> project docs instead; the console will erase it from YAML on every
> round-trip. After an export, sanity-check with a *semantic* diff (parse
> YAML, ignore comments/order) rather than a raw `git diff`, which will
> look alarmingly large.

### G. Hand-rolled migration via the Hasura CLI

For migrations the typed scaffolders don't cover (DML backfills,
multi-statement DDL, function/view bodies, server-introspection
migrations), use the CLI wrapper. It calls
[`hasura migrate create`](https://hasura.io/docs/2.0/hasura-cli/commands/hasura_migrate_create)
under the hood and writes a timestamped folder with empty `up.sql` /
`down.sql` files.

```bash
make hasura-env stage=local                # one-time per session: decrypt env
make create-dbml                           # pre-check: refresh snapshot
make hasura-migrate-create stage=local name=backfill_event_owner_ids
# → <hasura-root>/migrations/<db>/<13-digit-ts>_backfill_event_owner_ids/
#     up.sql      (empty — fill in)
#     down.sql    (empty — fill in)
```

Then:

1. Author `up.sql` and `down.sql` by hand. Both **must** be runnable
   independently — `up.sql` brings the DB forward, `down.sql` reverses
   every statement in `up.sql`.
2. If the change touches table shape: hand-author/refresh the matching
   `<hasura-root>/metadata/databases/<db>/tables/public_<table>.yaml`
   (the CLI does **not** touch metadata — only the typed scaffolders do).
   Admin role permissions remain forbidden (rule #6).
3. Apply + verify + commit:
   ```bash
   make hasura-migrate stage=local
   make create-dbml
   git add <hasura-root>/migrations/<db>/<ts>_<slug>/ \
           <hasura-root>/metadata/databases/<db>/tables/public_<table>.yaml \
           <schema-snapshot>
   git commit -m "feat(hasura): <message>"
   ```

**When to reach for this vs. the scaffolders:**
- Reach for the migrate-create target when the change is **not table-shape
  DDL** — pure DML, custom functions/views/triggers beyond the
  `function-trigger` scaffold, multi-step transactional migrations, or
  `--from-server` introspection imports.
- Otherwise prefer the typed scaffolders — they get the permission YAML,
  collision check, and naming right for free.

**Advanced CLI invocations** (typically not wrapped by the Makefile —
invoke `hasura` directly only if you genuinely need these, and still apply
via the project's apply target):

```bash
# Inline SQL — skips the manual fill-in step
hasura --project <hasura-root> --envfile <hasura-root>/console/.env.local \
       migrate create my_change --database-name <db> \
       --up-sql   "ALTER TABLE foo ADD COLUMN bar text;" \
       --down-sql "ALTER TABLE foo DROP COLUMN bar;"

# Introspect server-side schema into a fresh migration
hasura --project <hasura-root> --envfile <hasura-root>/console/.env.local \
       migrate create init --database-name <db> --from-server
```

### H. Event triggers — webhook configuration

Event triggers (the `event_triggers:` block in `public_<table>.yaml`) POST
to a backend webhook. The base-URL env var name and the webhook path
convention (example: `ACTION_BASE_URL` + `/internal/<path>`) are discovered
from the project's existing triggers and env files. **Always set the URL
with the plain `webhook` field and `{{ENV_VAR}}` substitution** — never
`webhook_from_env` + a Kriti `request_transform` url.

```yaml
event_triggers:
  - name: <table>_<purpose>
    definition:
      enable_manual: false
      insert:
        columns: '*'
      update:
        columns:            # only the columns that should fire it
          - col_a
          - col_b
    retry_conf:
      num_retries: 3
      interval_sec: 30
      timeout_sec: 60
    webhook: '{{ACTION_BASE_URL}}/internal/<path>'   # ✅ env-substituted at delivery time
    headers:
      - name: x-hasura-event-secret                  # example header name
        value_from_env: HASURA_EVENT_TRIGGER_SECRET  # example env var name
```

**Anti-pattern — do NOT use a request-transform template for the URL.** It
breaks silently: every event errors *before* any HTTP call
(`event_log.error=t, tries=0`, and `hdb_catalog.event_invocation_logs`
stays empty — no delivery is ever attempted):

```yaml
    webhook_from_env: ACTION_BASE_URL
    request_transform:
      template_engine: Kriti
      url: '{{$ACTION_BASE_URL}}/internal/<path>'   # ❌ Kriti: "Variable not in scope"
```

Why: the plain `webhook`/`handler` fields and the cron `webhook` field get
Hasura **environment-variable substitution** (`{{VAR}}` → value, resolved
at delivery time from the engine's process env). A `request_transform.url`
is a **Kriti** template — a *different* engine whose scope is only
`$base_url`, `$body`, `$session_variables`, `$query_params`, with **no
access to arbitrary env vars**. So both `{{$ACTION_BASE_URL}}` and
`{{ACTION_BASE_URL}}` fail inside a transform url; the only Kriti-valid
token would be `{{$base_url}}` (from `webhook_from_env`) — but prefer the
plain `webhook` field, which matches existing triggers in any project that
follows this convention.

Diagnose a dead trigger (admin secret via `hasura-query.sh`):
- `SELECT trigger_name, delivered, error, tries FROM hdb_catalog.event_log`
  — pre-flight failure looks like `error=t, tries=0`.
- `SELECT count(*) FROM hdb_catalog.event_invocation_logs` — `0` means no
  POST was ever attempted (template/URL never resolved); compare with
  `hdb_cron_event_invocation_logs` (crons use the working `{{ENV}}`
  pattern).

## Tooling reference

- **Scripts** live under `.claude/skills/hasura/scripts/`. Run from
  anywhere — they auto-locate the repo root.
- **Templates** under `.claude/skills/hasura/templates/` use `{{VAR}}`
  placeholders.
- **References** under `.claude/skills/hasura/references/` cover permission
  patterns, relationship naming, and enum tables — read these when defaults
  aren't enough.
- **Tests**: `.claude/skills/hasura/scripts/tests/run.sh` runs unit +
  integration tests. Run after editing libs or templates.

## Environment

Discover these from the repo (Makefile, docker-compose, env files) — the
values below are one project's example layout:

- Migration env files: `<hasura-root>/console/.env.<stage>` (may be
  encrypted on disk; decrypt via the project's env target, e.g.
  `make hasura-env stage=<stage>`, before querying).
- Local DB port: whatever docker-compose / the Makefile defines (example:
  `localhost:54324` via `make hasura-up stage=local`). The snapshot target
  may hardcode this endpoint — check it.
- Shared `updated_at` trigger function: many projects install one (example:
  `public.set_updated_at()` in a migration like
  `<ts>_add_uuid_defaults_and_updated_at_triggers`). If one exists, do not
  redefine it — new tables just add `CREATE TRIGGER
  set_<table>_updated_at`. Discover its name and installing migration from
  the migrations directory.

## Permission defaults applied by the scaffolder

Role names and the tenant column are the project's discovered conventions;
`user_id` and a tenant FK are the example shapes:

| Detected columns | Default scope |
|---|---|
| `user_id` only | user-row scope (`user_id = X-Hasura-User-Id`) |
| tenant column only | tenant-member scope (active member of the row's tenant) |
| both | hybrid (`_or` of the two) |
| neither | deny-by-default (`id = 00000000-0000-0000-0000-000000000000`) with TODO to replace |

A machine-to-machine role (example: `service`) gets empty filter `{}`. An
unauthenticated role (example: `anonymous`) is omitted for regular tables.
`admin` role is **never** declared. Enum tables are select-only. Soft-delete
projects filter `deleted_at` (e.g. `deleted_at: {_is_null: true}`) in every
user-visible permission.

See `references/permissions-patterns.md` for the full filter shapes.

## When something goes wrong

- **Snapshot refresh fails** (local Hasura down) → scaffolder falls back to
  the cached `<schema-snapshot>` with a warning and continues. Bring local
  Hasura up (example: `make hasura-up stage=local`) for a fresh snapshot.
- **Collision detected** → scaffolder prints the existing snapshot block +
  remediation (`Use add-column / rename instead.`) and exits. Never
  overwrites.
- **`hasura-query.sh` says the stage env file is missing** → run the env
  decrypt target (example: `make hasura-env stage=<stage>`) first.
- **Generated YAML breaks `metadata apply`** → it shouldn't (templates
  enforce filter-nesting indentation + a structural YAML test), but if it
  does: export metadata from local (example: `make hasura-export
  stage=local`) to normalize what's there, then diff against the generated
  YAML to spot the drift.

## Integrations

This skill activates only on a detected Hasura project
(`scripts/detect-hasura.mjs`; a non-Hasura repository gets nothing) and wires
into the rest of raftkit-dev:

- **capability-preflight / setup-project** — Hasura is a conditional capability
  in the provider registry; preflight reports its readiness and setup-project
  proposes activation only for a detected Hasura project, behind human
  approval. Discovery of the project's conventions (roots, stages, Make
  targets, secret env var names, tenancy relationship) runs through the same
  convention-discovery seam — nothing is assumed.
- **envx** — when the project keeps encrypted environments, the admin secret
  and endpoint are sourced through envx (the secret is never echoed; env files
  are never logged).
- **docs schema/architecture sync** — a schema change that lands here triggers
  the docs skill's change-tracking lifecycle so the schema and architecture
  docs stay in lockstep; the DBML snapshot refresh feeds that sync.
