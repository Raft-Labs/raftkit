#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/assert.sh"

# Build a fake repo structure in a tmp dir so we can run new-migration.sh
# without touching the real one.
tmp="$(mktemp -d)"
mkdir -p "$tmp/services/hasura/migrations/default" \
         "$tmp/services/hasura/metadata/databases/default/tables" \
         "$tmp/docs"

cat > "$tmp/Makefile" <<'EOF'
create-dbml:
	@true
EOF

cat > "$tmp/docs/schema.dbml" <<'EOF'
Table "users" {
  "id" uuid [pk, not null, default: `gen_random_uuid()`]
  "email" text [not null]
}

Table "families" {
  "id" uuid [pk, not null, default: `gen_random_uuid()`]
  "name" text [not null]
}
EOF

# Seed one pre-existing migration so race_safe_ts has to bump.
mkdir -p "$tmp/services/hasura/migrations/default/1900000000000_seed"
: > "$tmp/services/hasura/migrations/default/1900000000000_seed/up.sql"

SKILL_DIR="$(cd "$HERE/../.." && pwd)"
cd "$tmp"

HASURA_SKILL_AUTOCONFIRM=1 \
  export TENANCY_COLUMN=family_id TENANCY_REL=family TENANCY_MEMBER_REL=familyMembers
  "$SKILL_DIR/scripts/new-migration.sh" create-table meal_plans \
    --col "family_id:uuid:not_null:fk=families.id" \
    --col "title:text:not_null" \
    >/dev/null

# Verify a single migration directory was created with a timestamp >= 1900000000001
created="$(ls services/hasura/migrations/default | grep -v seed | grep meal_plans || true)"
[ -n "$created" ] || { echo "  ✗ no new migration dir created" >&2; exit 1; }
ts="${created%%_*}"
(( ts > 1900000000000 )) || { echo "  ✗ timestamp not race-safe: $ts" >&2; exit 1; }

# Verify up.sql contents
up="services/hasura/migrations/default/$created/up.sql"
assert_file_exists "$up"
up_content="$(<"$up")"
assert_contains "$up_content" "CREATE TABLE public.meal_plans"        "up has CREATE TABLE"
assert_contains "$up_content" "gen_random_uuid()"                     "uuid default"
assert_contains "$up_content" "set_meal_plans_updated_at"             "trigger present"
assert_contains "$up_content" "REFERENCES public.families(id)"        "FK rendered"
assert_contains "$up_content" "idx_meal_plans_family_id"              "FK index added"
assert_contains "$up_content" "idx_meal_plans_deleted_at_null"        "soft-delete index"

# Verify trailing newline on up.sql (Task 11 fix)
last_byte="$(tail -c 1 "$up" | od -An -c | tr -d ' ')"
[ "$last_byte" = "\\n" ] || { echo "  ✗ up.sql does not end with newline (got: $last_byte)" >&2; exit 1; }

# Verify down.sql
down="services/hasura/migrations/default/$created/down.sql"
down_content="$(<"$down")"
assert_contains "$down_content" "DROP TABLE IF EXISTS public.meal_plans CASCADE;" "down drops"

# Verify YAML
yaml="services/hasura/metadata/databases/default/tables/public_meal_plans.yaml"
assert_file_exists "$yaml"
yaml_content="$(<"$yaml")"
assert_contains "$yaml_content" "name: meal_plans"      "yaml table name"
assert_contains "$yaml_content" "name: family"          "family relationship"
assert_contains "$yaml_content" "familyMembers"         "family-scoped filter"
[[ "$yaml_content" != *"role: admin"* ]] || { echo "  ✗ admin block leaked into yaml" >&2; exit 1; }

# PyYAML structural check on the generated YAML (if available)
if command -v python3 >/dev/null 2>&1; then
  python3 - "$yaml" <<'PY'
import sys, yaml as y
with open(sys.argv[1]) as f:
    doc = y.safe_load(f)
for k in ("insert_permissions", "select_permissions", "update_permissions", "delete_permissions"):
    assert k in doc, f"missing top-level: {k}"
user_perm = next(p for p in doc["select_permissions"] if p["role"] == "user")["permission"]
flt = user_perm.get("filter")
assert isinstance(flt, dict) and "_and" in flt, \
    f"user SELECT filter not nested: {flt!r}"
print("integration YAML structural check OK", file=sys.stderr)
PY
fi

# Collision: re-running should fail. Simulate `make create-dbml` having
# refreshed the DBML with the new table (the fake Makefile is a no-op,
# so we patch the DBML directly to exercise the has_table guard).
cat >> docs/schema.dbml <<'EOF'

Table "meal_plans" {
  "id" uuid [pk, not null, default: `gen_random_uuid()`]
  "family_id" uuid [not null]
  "title" text [not null]
}
EOF
out="$(HASURA_SKILL_AUTOCONFIRM=1 "$SKILL_DIR/scripts/new-migration.sh" create-table meal_plans 2>&1 || true)"
assert_contains "$out" "already exists" "collision detected"

# Enum-with-values smoke (was previously broken by IFS leak — Task 11 fix verifies it)
HASURA_SKILL_AUTOCONFIRM=1 \
  "$SKILL_DIR/scripts/new-migration.sh" create-enum-table priority \
    --values "low,medium,high" \
    >/dev/null

enum_created="$(ls services/hasura/migrations/default | grep priority || true)"
[ -n "$enum_created" ] || { echo "  ✗ enum migration dir not created" >&2; exit 1; }
enum_up="services/hasura/migrations/default/$enum_created/up.sql"
enum_up_content="$(<"$enum_up")"
assert_contains "$enum_up_content" "CREATE TABLE public.priority"  "enum has CREATE TABLE"
assert_contains "$enum_up_content" "value text PRIMARY KEY"        "enum PK column"
assert_contains "$enum_up_content" "('low', NULL)"                 "enum value low"
assert_contains "$enum_up_content" "('medium', NULL)"              "enum value medium"
assert_contains "$enum_up_content" "('high', NULL)"                "enum value high"

enum_yaml="services/hasura/metadata/databases/default/tables/public_priority.yaml"
enum_yaml_content="$(<"$enum_yaml")"
assert_contains "$enum_yaml_content" "is_enum: true"     "enum yaml has is_enum"
assert_contains "$enum_yaml_content" "role: anonymous"   "enum readable by anonymous"

cd - >/dev/null
rm -rf "$tmp"
