---
Status: Draft | In Review | Approved | Implemented
Version: 1.0
Owner: <Name>
Last Updated: YYYY-MM-DD
---

# RBAC Matrix — Project-wide

Source-of-truth: `packages/auth/src/permissions.ts`. This doc is the human
overview — code is the actual enforcement.

## Roles

| Role | Tier | Description | Can Login | Multi-instance? |
|---|---|---|---|---|
| Platform Admin | Platform | Internal staff | Yes | Separate auth instance |
| Org Owner | Org | Created the org or transferred ownership | Yes | — |
| Org Admin | Org | Admin within an org | Yes | — |
| Staff — View | Org-sub | Read-only access | Yes | — |
| Staff — Write | Org-sub | Edit-but-not-assign | Yes | — |
| Staff — Assign | Org-sub | Assign resources | Yes | — |
| Staff — Payments | Org-sub | Record payments | Yes | — |
| Customer / End-user | Per-user | Public users (if applicable) | Yes | — |
| Member | Data | Stored as a record, not a logged-in user | No | — |

## Level 1 — Role × Module visibility

|  | Identity | Members | Money | Team | Operations | Platform |
|---|---|---|---|---|---|---|
| Platform Admin | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Org Owner | own org | own org | own org | own org | own org | own org |
| Org Admin | own org | own org | own org | own org | own org | own org (partial) |
| Staff — View | own org | own org | — | — | own org | — |
| Staff — Write | own org | own org | — | — | own org | — |
| Staff — Assign | own org | own org (partial) | — | — | own org | — |
| Staff — Payments | own org | own org | own org (read) | — | own org | — |
| Customer | own data | own | own | — | — | — |

## Level 2 — Per-module action matrices

### Module: Members

|  | Owner | Staff-V | Staff-W | Staff-A | Staff-P |
|---|---|---|---|---|---|
| list | ✓ | ✓ | ✓ | ✓ | ✓ |
| get | ✓ | ✓ | ✓ | ✓ | ✓ |
| create | ✓ | — | ✓ | — | — |
| update | ✓ | — | ✓ | — | — |
| assign-resource | ✓ | — | — | ✓ | — |
| unassign | ✓ | — | — | — | — |
| bulk-import | ✓ | — | — | — | — |
| export | ✓ | — | — | — | — |
| archive | ✓ | — | — | — | — |
| audit-view | ✓ | — | — | — | — |

(Repeat per module.)

## Level 3 — Field-level (only for sensitive fields)

### Entity: Member

| Field | Owner | Staff-V | Staff-W | Customer |
|---|---|---|---|---|
| `full_name` | RW | R | RW | R |
| `phone` | RW | R | RW | R |
| `gov_id_encrypted` | — | — | — | — |
| `gov_id_last4` | R | R | R | R |
| `photo_url` | RW | R | RW | R |
| `kyc_status` | RW | R | R | R |
| `bank_account` | RW | — | — | — |

Legend: R read · W write · RW both · - blocked

## Cross-tenant rules

| Rule | Implementation |
|---|---|
| Platform Admin can read all orgs | `admin` role bypass in all middleware |
| Platform Admin can impersonate any user | Signed JWT cookie + audit row per impersonate-action |
| Customer never sees other customer's data | Strict `customer_id` filter in every query |
| Org Owner cannot read another org's data | `org_id` filter enforced in `tenancy` middleware |

## Enforcement

### Middleware
```typescript
export const protectedProcedure = baseProcedure.use(requireAuth);
export const orgProcedure = protectedProcedure.use(requireActiveOrg);
export const ownerProcedure = orgProcedure.use(requireRole('owner'));
export const staffProcedure = (perm: StaffPermission) =>
  orgProcedure.use(requireStaffPermission(perm));
export const adminProcedure = baseProcedure.use(requireAdminAuth);
```

### Code generation from this matrix

```bash
# script/generate-permissions.ts reads this YAML and generates
# packages/auth/src/permissions.ts
```

## Audit

Every privileged action logged to `audit_log`:
- `actor_id`, `acting_as` (impersonation), `org_id`, `action`, `resource`,
  `resource_id`, `before`, `after`, `ip`, `ua`, `created_at`

## Anti-patterns

- **Permission checks inside route handlers** instead of middleware — duplicates matrix
- **Single "user" role + feature flags** as a substitute for real roles
- **Read permissions assumed open** — list explicit reads, especially for PII
- **Matrix in CLAUDE.md but not in code** — code is source-of-truth

## Related
- **Per-module Role × Action matrices:** in each `modules/<m>/module.md`
- **Auth provider config:** [tech-stack.md](../tech-stack.md)

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | YYYY-MM-DD | Initial draft |
