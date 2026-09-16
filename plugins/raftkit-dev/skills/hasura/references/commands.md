# Commands, column specs and tooling

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
