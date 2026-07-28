# Permission Filter Patterns

Row-level permission filter shapes per role and scope. Role names, session
variables, and the tenancy model below are the project's DISCOVERED
conventions — read them from the repository (existing permission blocks under
`<hasura-root>/metadata/databases/<source>/tables/`, the JWT/auth config) or
the Project Profile before scaffolding. Never assume them; the values shown
(`user`, `service`, `anonymous`, `X-Hasura-User-Id`, a tenant relationship)
are examples of one common shape.

## Roles (discovered — example set)

A typical project defines roles like these. Discover the actual role names
and their identity sources from existing metadata and the auth provider
config before writing any permission block.

| Role (example) | Source of identity (example) | Permissions block in YAML? |
|---|---|---|
| `user` | JWT claims (e.g. `X-Hasura-User-Id`, plus a tenant claim such as `X-Hasura-<Tenant>-Id`) | **Yes** — scoped filter |
| `service` | Service-to-service via admin secret + role header | **Yes** — empty filter `{}` |
| `anonymous` | No auth header / public traffic | Only on enum tables; otherwise omit |
| `admin` | Admin secret only | **No** — implicit full access. Declared admin blocks corrupt audits. |

## User-scoped table

Table has an ownership column (commonly `user_id uuid` referencing the users
table — discover the actual column from the schema). Default filter:

```yaml
filter:
  _and:
    - user_id:
        _eq: X-Hasura-User-Id
    - deleted_at:
        _is_null: true
```

## Tenant-scoped table

Many projects group rows under a tenant entity (an organization, team,
account, workspace, household, …). Discover the tenant column (e.g.
`<tenant>_id uuid`), the object relationship to the tenant table, and the
membership array relationship (e.g. `<tenant>.<tenantMembers>`) from the
existing metadata — never invent them. Example shape, using a discovered
tenant relationship:

```yaml
filter:
  _and:
    - <tenant>:                # discovered object relationship
        <tenantMembers>:       # discovered membership array relationship
          _and:
            - user_id:
                _eq: X-Hasura-User-Id
            - status:
                _eq: active    # only if membership has a status column
    - deleted_at:
        _is_null: true
```

## Hybrid (both an ownership column and a tenant column)

User can see a row if they own it OR they are a member of its tenant.

```yaml
filter:
  _and:
    - _or:
        - user_id:
            _eq: X-Hasura-User-Id
        - <tenant>:
            <tenantMembers>:
              _and:
                - user_id:
                    _eq: X-Hasura-User-Id
                - status:
                    _eq: active
    - deleted_at:
        _is_null: true
```

## None scope (deny-by-default)

When a table has neither an ownership column nor a tenant column, the
scaffolder emits a deny-by-default filter so the table is invisible to the
user-facing role until a human writes a real filter:

```yaml
filter:
  _and:
    - id:
        _eq: 00000000-0000-0000-0000-000000000000
```

The all-zero UUID matches no real row. Replace with an intentional filter
before applying to production.

## Column rules

- `INSERT` / `UPDATE` column lists **exclude**: `id`, `created_at`,
  `updated_at`, `deleted_at` (or the project's discovered equivalents).
- `SELECT` column list **includes everything**.
- For sensitive columns (encrypted tokens, hashed values), exclude from
  `SELECT` for the user-facing role and keep them on the service role only.

## Hard rules

1. **Never declare an `admin:` block.** Audits flag declared admin blocks as
   drift.
2. **Always include `deleted_at: { _is_null: true }`** in user-visible
   filters unless you explicitly want to expose tombstones.
3. **The service role gets `{}` filter** so background workers and queue
   consumers can read/write anything.
4. **The anonymous role only appears on enum tables** for public select.
