---
name: hasura
description: Work a project's Hasura schema — "create a new migration", "add a hasura table", "add an enum table", "scaffold a hasura migration", "query the dev hasura endpoint", "check migration status", "rollback a migration", "add hasura permissions". Scaffolds race-safe timestamped migrations with uuid defaults, updated_at triggers and permissions YAML, and wraps the project's own Make targets. Never edits an applied migration.
user-invocable: true
---

# hasura

The Hasura development loop: scaffold a migration, author its metadata, apply it through the project's own targets, refresh the schema snapshot, and query any stage. `raftkit-core:rules` apply.

**Conventions are discovered, never assumed.** The Hasura root, the snapshot and its target, the stage names, the env files, the database, the roles, the tenancy column, the secret names and the deploy model all come from this repository. Discover them once and cache them in `.raftkit/hasura.json`; re-derive when that file is missing or a command fails as though it were stale. Everything in `references/` written as a concrete path is an example of one project's naming. See `references/conventions.md`.

## Run

1. **Resolve the conventions** from `.raftkit/hasura.json` or by discovery.
2. **Scaffold** with `scripts/new-migration.sh`. It prints the `up.sql`, the `down.sql` and the permissions YAML and asks before writing anything. Column specs, every subcommand and the tooling are in `references/commands.md`.
3. **Apply and refresh.** Run the project's own migrate target, then refresh the schema snapshot. A DDL change refreshes the snapshot before and after, so the committed schema never drifts from the database.
4. **Query** any stage ad hoc with `scripts/hasura-query.sh`, reading the stage's own env file.

Workflows for each change type, and the permission defaults the scaffolder applies, are in `references/workflows.md`. Table and relationship naming is in `references/relationship-naming.md`, enum tables in `references/enum-tables.md`, permission shapes in `references/permissions-patterns.md`.

## Safety rules

- **Never edit an applied migration.** One that has run anywhere is immutable: write a new one.
- **Apply only through the project's own migrate target**, never `hasura migrate apply` directly.
- **Every migration is reversible**: an `up.sql` and a `down.sql` that actually reverses it, in one atomic commit per schema change, so a revert is one commit.
- **Confirm every destructive change** before acting: dropping or renaming a column or table, deleting a migration, or reapplying one.
- **Local-first: migrate only `stage=local`.** Development and production migrate through the pipeline, never from a session.
- **Never declare the `admin` role** in permissions YAML: Hasura grants it implicitly, and declaring it is forbidden in YAML.
- **Never echo a secret.** Env files are decrypted through the project's own target and their values stay redacted in any output, the admin secret included.
- **Never overwrite a timestamp collision.** The scaffolder prints the existing block and the remedy, then exits.
- **Never push to a protected branch** without per-action approval.

## Integrations

Encrypted env files are read through `envx`, the project's own seam, never decrypted by hand. A schema or architecture change hands its change set to `raftkit-dev:docs` so the schema docs stay in step. Activation in a repository is proposed by `raftkit-dev:setup`, whose engine preflight confirms what this skill calls.
