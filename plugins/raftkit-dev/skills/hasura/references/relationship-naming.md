# Relationship Naming Conventions

Names live in the table metadata YAML under
`<hasura-root>/metadata/databases/<source>/tables/` (e.g.
`public_<table>.yaml`). Discover `<hasura-root>` and the source name from
the repository (config.yaml, the metadata directory) — never assume them.
The scaffolder auto-derives names per these rules.

## Object relationships (table-side of an FK)

| FK column | Target table | Derived name | Rationale |
|---|---|---|---|
| `created_by` | `users` | `createdByUser` | Suffix `_by` → `_user` to disambiguate from boolean-style columns |
| `updated_by` | `users` | `updatedByUser` | Same |
| `account_id` | `accounts` | `account` | Strip `_id`, camelCase |
| `parent_item_id` | `items` | `parentItem` | Compound `_id` stripped |
| `status` | `order_status` (enum) | `orderStatus` | Enum FK: name is the camelCase of the target enum table |
| `provider` | `payment_provider` (enum) | `paymentProvider` | Same |

## Array relationships (one-to-many, this table referenced by another)

Take the referencing table name and camelCase it. If the project's tables
are already plural (a discovered convention — check existing metadata),
the derived name stays as-is.

| Referencing table | Derived name |
|---|---|
| `order_items` | `orderItems` |
| `team_members` | `teamMembers` |
| `notifications` | `notifications` |

## Edge cases

- **Self-referential FK** (e.g., `parent_item_id` on `items`): object rel
  is `parentItem`; the inbound array rel is `childItems` (manually
  overridden after generation).
- **Multiple FKs to the same table**: the scaffolder will produce default
  names that may collide. Override one in the YAML before applying.
- **Enum without an obvious owning context**: if the FK isn't on an
  obvious owning table (rare), use the bare target name camelCased.

## Why this matters

Client code reads Hasura via GraphQL codegen (e.g. Apollo), and field
names are derived from the relationship names. Inconsistent names lead to
inconsistent client code and confused codegen output.
