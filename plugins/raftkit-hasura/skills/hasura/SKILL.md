---
name: hasura
description: Work a project's Hasura schema — "create a new migration", "add a hasura table", "add an enum table", "scaffold a hasura migration", "query the dev hasura endpoint", "check migration status", "rollback a migration", "add hasura permissions". Scaffolds race-safe timestamped migrations with uuid defaults, updated_at triggers and permissions YAML, and wraps the project's own Make targets. Never edits an applied migration.
user-invocable: true
---

# hasura

Scaffold a migration and its metadata, apply it through the project's own targets, refresh the schema snapshot, and query any stage. Load `raftkit-core:rules` first unless it is already in this conversation.

**Conventions are discovered, never assumed.** The Hasura root, the snapshot and its target, the stage names, the env files, the database, the roles, the tenancy column, the secret names and the deploy model all come from this repository. `${CLAUDE_SKILL_DIR}/scripts/detect-hasura.mjs --root <repo> --write` records the scaffolder's inputs in `.raftkit/hasura.json`; its schema and when to re-derive are in `references/conventions.md`. Everything in `references/` written as a concrete path is an example of one project's naming.

## Run

1. **Resolve the conventions** from `.raftkit/hasura.json` or by discovery, and run the scaffolder with its `env` set.
2. **Scaffold** with `${CLAUDE_SKILL_DIR}/scripts/new-migration.sh`, which never prompts: `--dry-run` prints the `up.sql`, the `down.sql` and the permissions YAML, and `--write` writes them. Column specs and every subcommand are in `references/commands.md`.
3. **Apply and refresh.** Run the project's own migrate target, then refresh the schema snapshot. A DDL change refreshes the snapshot before and after, so the committed schema never drifts.
4. **Query** any stage ad hoc with `${CLAUDE_SKILL_DIR}/scripts/hasura-query.sh`, reading the stage's own env file.

Workflows per change type and the scaffolder's permission defaults: `references/workflows.md`. Naming: `references/relationship-naming.md`. Enum tables: `references/enum-tables.md`. Permission shapes: `references/permissions-patterns.md`. A `scripts/` path in a reference is relative to `${CLAUDE_SKILL_DIR}`.

## Safety rules

- **Never edit an applied migration.** One that has run anywhere is immutable: write a new one.
- **Apply only through the project's own migrate target**, never `hasura migrate apply` directly.
- **Every migration is reversible**: an `up.sql` and a `down.sql` that actually reverses it, in one atomic commit per schema change, so a revert is one commit.
- **Confirm every destructive change** before acting: dropping or renaming a column or table, deleting a migration, or reapplying one. Batch them into one message, each with its dry run or command; only an explicit go passes `--confirmed` or runs the target.
- **Local-first: migrate only `stage=local`.** Development and production migrate through the pipeline, never from a session.
- **Never declare the `admin` role** in permissions YAML: Hasura grants it implicitly, and declaring it is forbidden in YAML.
- **Never echo a secret.** Env files are decrypted through the project's own target and their values stay redacted in any output, the admin secret included.
- **Never overwrite a timestamp collision.** The scaffolder prints the existing block and the remedy, then exits.
- **Never push to a protected branch** without per-action approval.

**STOP** — approve the destructive changes, edit to change, or decline.

## Integrations

Encrypted env files are read through `envx`, the project's own seam, never decrypted by hand. A schema or architecture change hands its change set to `raftkit-dev:docs` so the schema docs stay in step. Activation in a repository is proposed by `raftkit-dev:setup`, whose engine preflight confirms what this skill calls.
