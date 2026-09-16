# RBAC Matrix Guide

Roles without a permission matrix are decoration. This file teaches the
skill how to force a real matrix into existence.

## Required before exiting the auth phase

The auth phase cannot exit without a drafted matrix: a role × top-level-resource × action matrix must exist before moving on. Stub if needed, but at least the row/column scaffold.

## Three nested matrices

### Level 1 — Role × Module (visibility)

> Can this role see this module at all?

```
             | Identity | Members | Money | Team | Operations | Platform |
Owner        |    ✓     |    ✓    |   ✓   |  ✓   |     ✓      |    ✓     |
Manager-View |    own   |    ✓    |   —   |  —   |     ✓      |    —     |
Manager-Write|    own   |    ✓    |   —   |  —   |     ✓      |    —     |
Manager-Pay  |    own   |    ✓    |   ✓   |  —   |     ✓      |    —     |
Platform     |    ✓     |    ✓    |   ✓   |  ✓   |     ✓      |    ✓     |
```

Legend: ✓ full · own = only own records · partial · — blocked

### Level 2 — Role × Module × Action (capability)

Per module. Example for Members:

```
Action            | Owner | Manager-V | Manager-W | Manager-P |
list              |   ✓   |    ✓      |    ✓      |    ✓      |
get               |   ✓   |    ✓      |    ✓      |    ✓      |
create            |   ✓   |    —      |    ✓      |    —      |
update            |   ✓   |    —      |    ✓      |    —      |
assign-project    |   ✓   |    —      |    —      |    —      |
deactivate        |   ✓   |    —      |    —      |    —      |
bulk-import       |   ✓   |    —      |    —      |    —      |
export            |   ✓   |    —      |    —      |    —      |
delete (hard)     |   —   |    —      |    —      |    —      |
archive (soft)    |   ✓   |    —      |    —      |    —      |
audit-view        |   ✓   |    —      |    —      |    —      |
```

### Level 3 — Role × Field (field-level when sensitive)

Only when needed (PII fields, financial fields):

```
Field                 | Owner | Manager | Customer |
member.full_name      |  RW   |   R     |    R     |
member.gov_id_full    |  -    |   -     |    -     |  (never readable)
member.gov_id_last4   |  R    |   R     |    R     |
member.phone          |  RW   |   R     |    R     |
member.kyc_doc        |  R    |   -     |    R     |
invoice.amount        |  RW   |   R*    |    R     |  (* only Manager-Pay)
audit_log.*           |  R    |   -     |    -     |
```

Legend: R read · W write · RW both · - blocked

## How to interview the user

Skill must ask incrementally, never dump a blank matrix.

### Step 1 — Confirm role list
> "Roles you mentioned: Owner, Manager, Platform Admin. Should Manager be
> one role or split into permission tiers? In a prior project we split
> into 6 (view, write, assign, payments, etc.). Recommendation?"

### Step 2 — For each role × module, ask visibility
> "Does Manager see the Money module at all? If yes — own org only or
> all? If no — what's the user-facing message when they try?"

### Step 3 — For each visible module × action, ask capability
> "On Members → 'deactivate' action: owner only, or manager-write too? In
> a prior project we made deactivate owner-only because it triggers
> refund logic."

### Step 4 — For sensitive fields, ask field-level
> "Member has a government ID number. Who reads the full number vs only
> last 4 digits? In a prior project no one read the full number — it was
> only stored encrypted for re-verification."

## Where the matrix lives in generated docs

- **`docs/project/modules/<module>/module.md`** — Role × Action matrix per
  module (the actionable one)
- **`docs/project/shared/rbac.md`** — Role × Module visibility matrix
  (cross-module) + Field-level matrix for sensitive entities
- **Implementation source-of-truth**: `packages/auth/permissions.ts`
  generated from this matrix

## Common patterns from real projects

### Multi-tenant SaaS with permission DSL
```ts
ac, roles: orgOwner, teamMember, platformAdmin
permissions: { resource × actions } via custom DSL
enforced in middleware: assertPermission(role, resource, actions)
```

### 6-permission manager tiers
- manager:view
- manager:write
- manager:assign
- manager:payments
- manager:reports
- manager:settings

User can hold multiple permissions; OR semantics.

### System-defined RBAC for household roles
- 17 permissions × 5 household roles (parent, partner, caregiver,
  family, self)
- admin role has implicit full access

## Anti-patterns to flag

- **Single "user" role with feature flags as permissions** — leads to
  permission spaghetti. Use a real role with multiple permissions.
- **Permissions checked inline in handlers** — duplicates the matrix.
  Use middleware (`adminProcedure`, `managerProcedure(permission)`).
- **Read permissions ignored** — most matrices only cover writes. List
  reads explicitly, especially for PII fields.
- **Matrix in CLAUDE.md but not in code** — the matrix lives in
  `packages/auth/permissions.ts`. CLAUDE.md just references it.
