# Enum Tables

Hasura represents enums as small lookup tables marked `is_enum: true` in metadata. This pattern keeps types referential-integrity-safe at the DB level while still giving Hasura first-class GraphQL enum types.

## Shape

```sql
CREATE TABLE public.<enum_name> (
  value text PRIMARY KEY,
  description text
);
```

- **Primary key column is `value`** (text).
- `description` is optional, used by admin UIs to explain the meaning.
- Name is typically plural-shaped: `event_status`, `calendar_provider`, `notification_type`.

## Seeding values

Seed inside the same migration's `up.sql`:

```sql
INSERT INTO public.event_status (value, description) VALUES
  ('draft', 'Not yet published'),
  ('published', 'Visible to participants'),
  ('cancelled', 'Cancelled by owner');
```

## Adding values later

Create a new migration with just an `INSERT … ON CONFLICT DO NOTHING`:

```sql
INSERT INTO public.event_status (value, description)
VALUES ('archived', 'Past, not deletable')
ON CONFLICT (value) DO NOTHING;
```

## Metadata YAML

```yaml
table:
  name: event_status
  schema: public
is_enum: true
array_relationships: []   # filled if any table FKs into this
select_permissions:
  - role: user
    permission: { columns: [value, description], filter: {}, allow_aggregations: true }
  - role: service
    permission: { columns: [value, description], filter: {}, allow_aggregations: true }
  - role: anonymous
    permission: { columns: [value, description], filter: {}, allow_aggregations: true }
```

## FK columns into enum tables

When another table FKs into an enum, the FK column is the enum's `value` text:

```sql
ALTER TABLE public.events
  ADD COLUMN status text NOT NULL DEFAULT 'draft'
  REFERENCES public.event_status(value);
```

Hasura then emits a GraphQL enum type and constrains the field. The object relationship name follows the enum-FK convention: camelCase of the target enum table → `eventStatus`.

## What never to do

- Don't use Postgres native `ENUM` types — Hasura doesn't track them as enums.
- Don't add `created_at` / `updated_at` / `deleted_at` to enum tables — they're append-only references.
- Don't allow `INSERT` / `UPDATE` / `DELETE` from `user` or `service` roles in Hasura; seed via migrations only.
