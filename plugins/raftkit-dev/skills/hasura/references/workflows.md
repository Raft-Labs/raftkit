# Workflows

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
