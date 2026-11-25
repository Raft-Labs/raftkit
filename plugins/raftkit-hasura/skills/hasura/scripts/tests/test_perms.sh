#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/assert.sh"
source "$HERE/../lib/perms.sh"

export TENANCY_COLUMN=family_id TENANCY_REL=family TENANCY_MEMBER_REL=familyMembers

# The structural YAML checks below need PyYAML, not just python3 — check both
# once so a python3-present-but-no-pyyaml environment skips gracefully
# instead of a raw traceback that reads like a real failure.
PYYAML_OK=0
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  PYYAML_OK=1
else
  echo "  (skip: python3+PyYAML not available — structural YAML checks skipped, not failed)" >&2
fi

# detect_scope <comma-separated col names>
assert_eq "user"   "$(detect_scope "id,user_id,title,deleted_at")"        "user_id only"
assert_eq "tenant" "$(detect_scope "id,family_id,title,deleted_at")"      "tenancy column only"
assert_eq "hybrid" "$(detect_scope "id,user_id,family_id,deleted_at")"    "both"
assert_eq "none"   "$(detect_scope "id,title")"                           "neither"

# emit_user_filter prints a YAML fragment for the detected scope
out="$(emit_user_filter user)"
assert_contains "$out" "user_id"             "user filter mentions user_id"
assert_contains "$out" "X-Hasura-User-Id"    "uses session var"
assert_contains "$out" "_is_null: true"      "soft-delete filter"

out="$(emit_user_filter tenant)"
assert_contains "$out" "familyMembers" "family filter uses array rel"
assert_contains "$out" "active"        "active member only"

out="$(emit_user_filter hybrid)"
assert_contains "$out" "_or"           "hybrid filter uses _or"

# emit_full_yaml prints insert/select/update/delete blocks for 'user' + service
yaml="$(USER_INSERT_COLS='title,user_id' USER_SELECT_COLS='id,title,user_id,created_at,updated_at,deleted_at' \
        emit_full_yaml regular user)"
assert_contains "$yaml" "insert_permissions" "has insert"
assert_contains "$yaml" "select_permissions" "has select"
assert_contains "$yaml" "update_permissions" "has update"
assert_contains "$yaml" "delete_permissions" "has delete"
assert_contains "$yaml" "role: service"      "has service"
[[ "$yaml" != *"role: admin"* ]] || { echo "  ✗ admin role must be omitted" >&2; exit 1; }
[[ "$yaml" != *"role: anonymous"* ]] || { echo "  ✗ anonymous must be omitted for regular table" >&2; exit 1; }

# Enum tables: only SELECT, all three readable roles
yaml="$(emit_full_yaml enum)"
assert_contains "$yaml" "is_enum: true"        "enum marker"
assert_contains "$yaml" "role: anonymous"      "enum readable by anonymous"
[[ "$yaml" != *"insert_permissions"* ]] || { echo "  ✗ enum must not have insert" >&2; exit 1; }

# Structural test: regular YAML must parse and the user role's filter must be
# a real nested filter (not null/none).
if [ "$PYYAML_OK" = 1 ]; then
  yaml="$(USER_INSERT_COLS='title,user_id' \
          USER_SELECT_COLS='id,title,user_id,created_at,updated_at,deleted_at' \
          emit_full_yaml regular user)"
  python3 - "$yaml" <<'PY'
import sys, yaml as y
doc = y.safe_load(sys.argv[1])
# Required top-level blocks
for k in ("insert_permissions", "select_permissions", "update_permissions", "delete_permissions"):
    assert k in doc, f"missing top-level: {k}"
# User role's SELECT filter must be a nested dict with _and, not None/null
sel = doc["select_permissions"]
user_perm = next(p for p in sel if p["role"] == "user")["permission"]
flt = user_perm.get("filter")
assert isinstance(flt, dict) and "_and" in flt, \
    f"user SELECT filter not nested: {flt!r}"
# Same for UPDATE and DELETE filters and INSERT check
upd = next(p for p in doc["update_permissions"] if p["role"] == "user")["permission"]
assert isinstance(upd.get("filter"), dict) and "_and" in upd["filter"], \
    f"user UPDATE filter not nested: {upd.get('filter')!r}"
ins = next(p for p in doc["insert_permissions"] if p["role"] == "user")["permission"]
assert isinstance(ins.get("check"), dict) and "_and" in ins["check"], \
    f"user INSERT check not nested: {ins.get('check')!r}"
dele = next(p for p in doc["delete_permissions"] if p["role"] == "user")["permission"]
assert isinstance(dele.get("filter"), dict) and "_and" in dele["filter"], \
    f"user DELETE filter not nested: {dele.get('filter')!r}"
# admin must NOT be declared
for k in ("insert_permissions","select_permissions","update_permissions","delete_permissions"):
    roles = {p["role"] for p in doc[k]}
    assert "admin" not in roles, f"admin must not appear in {k}"
print("YAML structural check OK", file=sys.stderr)
PY
fi

# Family scope structural test
if [ "$PYYAML_OK" = 1 ]; then
  yaml="$(USER_INSERT_COLS='title,family_id' \
          USER_SELECT_COLS='id,title,family_id,created_at,updated_at,deleted_at' \
          emit_full_yaml regular tenant)"
  python3 - "$yaml" <<'PY'
import sys, yaml as y
doc = y.safe_load(sys.argv[1])
sel = next(p for p in doc["select_permissions"] if p["role"] == "user")["permission"]
flt = sel["filter"]
# Must traverse family → familyMembers → user_id
assert "_and" in flt
deep = str(flt)
assert "familyMembers" in deep, f"family scope missing familyMembers: {deep}"
assert "X-Hasura-User-Id" in deep, f"family scope missing X-Hasura-User-Id: {deep}"
print("Family YAML structural check OK", file=sys.stderr)
PY
fi

# Enum YAML structural test
if [ "$PYYAML_OK" = 1 ]; then
  yaml="$(emit_full_yaml enum)"
  python3 - "$yaml" <<'PY'
import sys, yaml as y
doc = y.safe_load(sys.argv[1])
assert doc.get("is_enum") is True, f"is_enum: {doc.get('is_enum')!r}"
assert "select_permissions" in doc
for k in ("insert_permissions","update_permissions","delete_permissions"):
    assert k not in doc, f"enum must not have {k}"
roles = {p["role"] for p in doc["select_permissions"]}
assert roles == {"user","service","anonymous"}, f"enum roles: {roles}"
print("Enum YAML structural check OK", file=sys.stderr)
PY
fi

# None scope must produce a deny-by-default filter, never null
if [ "$PYYAML_OK" = 1 ]; then
  yaml="$(USER_INSERT_COLS='id' USER_SELECT_COLS='id' \
          emit_full_yaml regular none)"
  python3 - "$yaml" <<'PY'
import sys, yaml as y
doc = y.safe_load(sys.argv[1])
sel = next(p for p in doc["select_permissions"] if p["role"] == "user")["permission"]
flt = sel["filter"]
assert isinstance(flt, dict), f"none scope must emit a real filter, got: {flt!r}"
# Deny-by-default: filter must not be empty or null
assert flt, "none-scope filter must not be empty"
print("None-scope deny-by-default check OK", file=sys.stderr)
PY
fi
