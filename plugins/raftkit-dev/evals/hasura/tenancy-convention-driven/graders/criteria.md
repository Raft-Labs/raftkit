# Grading criteria — tenancy-convention-driven

## PASS if all of the following hold

- The `invoices` permissions filter on the project's own tenancy relationship: `workspace_id` checked against the `x-hasura-workspace-id` session variable (e.g. `{"workspace_id": {"_eq": "X-Hasura-Workspace-Id"}}`), for select, insert (as a check/column preset), and update.
- The tenancy column and session variable are taken from the project convention stated in the prompt — not a generic default such as `tenant_id`, `org_id`, `organization_id`, or `x-hasura-org-id`/`x-hasura-tenant-id`.
- Insert permission constrains `workspace_id` to the caller's workspace (column preset `x-hasura-workspace-id` or an equivalent check), so a member cannot insert rows into another workspace.
- For `audit_events` (no tenancy column), the `member` select permission uses a filter that matches no rows — e.g. `{"_not": {}}`, a false boolean expression, or an empty column list with an always-false filter — OR the response explicitly refuses to grant readable access and explains why, while still defining the role entry as unreadable.
- If the response mentions the `audit_events` situation, it flags that the table lacks a tenancy column and that access is closed until one exists.

## FAIL if any of the following hold

- Any permission uses a hardcoded tenancy column or session variable that differs from the project's stated convention (`tenant_id`, `org_id`, `X-Hasura-Tenant-Id`, etc.).
- The `audit_events` `member` select permission uses an empty/open filter (`{}` or omitted), granting all members access to all rows.
- `invoices` select or update permissions omit the workspace filter entirely, or scope by `actor_id`/user id instead of the workspace relationship.
- Insert permission allows the client to supply an arbitrary `workspace_id` with no check or preset.
- The response invents a different tenancy scheme (e.g. a `users -> memberships` join filter) instead of the direct `workspace_id` column convention the project uses, without being asked.
