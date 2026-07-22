#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/assert.sh"
source "$HERE/../lib/dbml_grep.sh"

# ---- Fixture A: dotted form (db2dbml emits this for non-public or some versions)
tmp="$(mktemp -d)"
cat > "$tmp/schema.dbml" <<'EOF'
Table "public"."events" {
  "id" uuid [pk, not null, default: `gen_random_uuid()`]
  "title" text [not null]
  "family_id" uuid
}

Table "public"."users" {
  "id" uuid [pk, not null, default: `gen_random_uuid()`]
  "email" text [not null]
}
EOF

assert_exit_code 0 "dotted: has-table events"        has_table "$tmp/schema.dbml" events
assert_exit_code 1 "dotted: has-table missing"       has_table "$tmp/schema.dbml" meal_plans
assert_exit_code 0 "dotted: has-column events.title" has_column "$tmp/schema.dbml" events title
assert_exit_code 1 "dotted: has-column events.x"     has_column "$tmp/schema.dbml" events nonexistent

block="$(show_table "$tmp/schema.dbml" events)"
assert_contains "$block" '"title" text [not null]' "dotted: block contains title"
[[ "$block" != *'"public"."users"'* ]] || { echo "  ✗ dotted: block leaked into next table" >&2; exit 1; }

rm -rf "$tmp"

# ---- Fixture B: bare form (db2dbml emits this for public schema in this repo)
tmp="$(mktemp -d)"
cat > "$tmp/schema.dbml" <<'EOF'
Table "hdb_catalog"."hdb_version" {
  "version" text [not null]
}

Table "events" {
  "id" uuid [pk, not null, default: `gen_random_uuid()`]
  "title" text [not null]
  "family_id" uuid
}

Table "users" {
  "id" uuid [pk, not null, default: `gen_random_uuid()`]
  "email" text [not null]
}
EOF

assert_exit_code 0 "bare: has-table events"        has_table "$tmp/schema.dbml" events
assert_exit_code 1 "bare: has-table missing"       has_table "$tmp/schema.dbml" meal_plans
assert_exit_code 0 "bare: has-column events.title" has_column "$tmp/schema.dbml" events title
assert_exit_code 1 "bare: has-column events.x"     has_column "$tmp/schema.dbml" events nonexistent

# A bare-name lookup must NOT match a non-public table (hdb_catalog.hdb_version)
assert_exit_code 1 "bare: has-table hdb_version is not in public" has_table "$tmp/schema.dbml" hdb_version

block="$(show_table "$tmp/schema.dbml" events)"
assert_contains "$block" '"title" text [not null]' "bare: block contains title"
[[ "$block" != *'Table "users"'* ]] || { echo "  ✗ bare: block leaked into next table" >&2; exit 1; }
[[ "$block" != *'hdb_version'* ]]   || { echo "  ✗ bare: block leaked from previous table" >&2; exit 1; }

rm -rf "$tmp"

# ---- Fixture C: real repo DBML (smoke test against actual docs/schema.dbml)
REAL_DBML="$HERE/../../../docs/schema.dbml"
if [ -f "$REAL_DBML" ]; then
  assert_exit_code 0 "real: has-table events"  has_table "$REAL_DBML" events
  assert_exit_code 0 "real: has-table users"   has_table "$REAL_DBML" users
  assert_exit_code 1 "real: has-table absent"  has_table "$REAL_DBML" this_table_definitely_should_not_exist_xyzzy
  block="$(show_table "$REAL_DBML" events)"
  [ -n "$block" ] || { echo "  ✗ real: show_table events returned empty" >&2; exit 1; }
fi
