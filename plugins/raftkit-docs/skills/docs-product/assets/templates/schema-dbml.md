---
Status: Draft | In Review | Approved | Implemented
Version: 1.0
Owner: <Name>
Last Updated: YYYY-MM-DD
Type: DBML overview
---

# DBML Schema — Project-wide

The full database schema in DBML format. Source-of-truth for the Hasura
archetype; reference-only for Drizzle archetype (where Drizzle schema files
are the source of truth).

**File location:** `services/postgres/schema.dbml`
**Render online:** https://dbdiagram.io

## Project header

```dbml
Project <project_name> {
  database_type: 'PostgreSQL'
  Note: '<project description>'
}
```

## Identity tables

```dbml
Table user {
  id text [pk]                  // Better Auth uses text; Cognito too
  email text [unique, not null]
  name text
  image text
  email_verified boolean [default: false]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
}

Table organization {
  id text [pk]
  name text [not null]
  slug text [unique, not null]
  logo text
  metadata jsonb
  created_at timestamptz [not null, default: `now()`]
}

Table member {
  id uuid [pk, default: `gen_random_uuid()`]
  user_id text [not null, ref: > user.id]
  organization_id text [not null, ref: > organization.id]
  role text [not null, default: 'member']
  permissions text[]
  created_at timestamptz [not null, default: `now()`]
  Indexes {
    (user_id, organization_id) [unique]
  }
}
```

## Per-module tables

(One section per module. Include all tables that module owns.)

### Module: Invoices

```dbml
Table invoice {
  id uuid [pk, default: `gen_random_uuid()`]
  organization_id text [not null, ref: > organization.id]
  customer_name text [not null]
  customer_phone text [not null]
  gov_id_encrypted bytea       // encrypted government ID number, if collected
  gov_id_last4 char(4)
  attachment_url text
  status text [not null, default: 'draft', ref: > invoice_status_enum.value]
  issued_at timestamptz [not null, default: `now()`]
  paid_at timestamptz
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
  deleted_at timestamptz
  Indexes {
    (organization_id, status) [name: 'invoice_org_status_idx']
    (organization_id, issued_at) [name: 'invoice_org_issued_idx']
    (organization_id) [partial: 'deleted_at is null', name: 'invoice_active_idx']
  }
}

Table invoice_status_enum {
  value text [pk]
  description text
  Note: 'Hasura @enum'
}
```

(Repeat per module.)

## Enum tables (Hasura @enum pattern)

```dbml
Table <enum_name>_enum {
  value text [pk]
  description text
  Note: 'Hasura @enum'
}
```

## Foreign-key reference index

| Table | FK | References | On Delete |
|---|---|---|---|
| `<child>` | `<parent>_id` | `<parent>.id` | CASCADE |
| `<child>` | `created_by` | `user.id` | RESTRICT |

## Index rationale

Every index should have a stated purpose. Audit by running:

```sql
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;
```

Drop unused indexes.

## Schema versioning

Migrations under `services/hasura/migrations/default/<timestamp>-<slug>/`
or `packages/db/src/migrations/<n>_<slug>.sql`. Never edit applied
migrations — always add a new one.

## Related
- **Drizzle source-of-truth:** `packages/db/src/schema/` (Archetype A)
- **Hasura migrations:** `services/hasura/migrations/default/` (Archetype B)

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | YYYY-MM-DD | Initial DBML draft |
