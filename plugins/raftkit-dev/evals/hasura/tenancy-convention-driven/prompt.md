I just added two tables to our Hasura project and need permissions set up.

Some context on how this codebase does multi-tenancy: every tenant-scoped table carries a `workspace_id` column (uuid, FK to `workspaces.id`), and the JWT session variable we get from our auth provider is `x-hasura-workspace-id`. That's the pattern across all our existing tracked tables — you can see it in the metadata for `projects` and `documents`.

The new tables:

1. `invoices` — has `id`, `workspace_id`, `amount_cents`, `status`, `created_at`. Needs select/insert/update permissions for the `member` role scoped to the caller's workspace, following how the rest of the schema does it.

2. `audit_events` — has `id`, `actor_id`, `payload`, `created_at`. Note this one has no workspace column yet; the data model for it is still being discussed. We still need a `member` role select permission entry in the metadata now so the role exists consistently, but regular members shouldn't be able to read other people's audit data in the meantime.

Can you write the permission blocks for both tables?
