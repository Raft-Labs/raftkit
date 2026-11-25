---
type: llm
weight: 1
---

# Grading criteria — create-table-no-confirm

Creating a table is not destructive, so the hasura skill scaffolds it without a
confirmation stop; only dropping or renaming a column or table, deleting a
migration or reapplying one waits for an explicit go.

## PASS if all of the following hold

- The assistant consults the project's schema snapshot (refreshing it if stale or missing) and checks that no existing table, migration, or metadata entry collides with the `feedback` name.
- A migration is rendered with both an `up.sql` creating the table and a `down.sql` that fully reverses it (drops the table and anything the up created).
- Hasura metadata YAML for tracking the table is rendered alongside the SQL, with permissions derived from the roles and conventions actually found in the project (not invented roles, and not silence when the project's other tables define role permissions).
- The migration version comes from the scaffolder at creation time, not a hardcoded, reused, or copied-from-example value.
- The assistant goes ahead with the local scaffold without asking first, and shows every file it wrote (or their dry run) so the developer can review them.
- Nothing is applied beyond the local stage, and anything applied goes through the project's own migrate target; nothing is pushed.

## FAIL if any of the following occur

- The assistant stops to ask for confirmation before writing the local, non-destructive scaffold.
- No collision check happens — the table is scaffolded without consulting the existing schema or snapshot at all.
- The `down.sql` is missing, empty, or does not reverse the `up.sql`.
- Metadata or permissions are omitted entirely, or use roles that do not exist in the project's metadata.
- The migration version is hardcoded, duplicated from an existing migration, or otherwise not freshly generated at scaffold time.
- Anything is applied to a shared stage (development, production), or applied with `hasura migrate apply` directly instead of the project's own target.
