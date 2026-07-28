# Permission scope detection + YAML emission. Source, do not execute.
#
# Tenancy is convention-driven, not hardcoded to any one project's model. The
# tenant relationship is discovered from the repository (or the Project
# Profile) and passed in via env vars; the deny-by-default fallback is
# preserved when no tenancy is detected. Set these before sourcing/calling:
#   TENANCY_COLUMN        the FK column that scopes a row to a tenant
#                         (e.g. family_id, org_id, team_id); empty = none
#   TENANCY_REL           the object relationship to the tenant (e.g. family)
#   TENANCY_MEMBER_REL    the array relationship to memberships
#                         (e.g. familyMembers, members)
#   TENANCY_STATUS_FIELD  the membership-status field (default: status)
#   TENANCY_STATUS_VALUE  the active-membership value (default: active)
# The user column is X-Hasura-User-Id via ${TENANCY_MEMBER_COLUMN:-user_id}.

TENANCY_COLUMN="${TENANCY_COLUMN:-}"
TENANCY_REL="${TENANCY_REL:-}"
TENANCY_MEMBER_REL="${TENANCY_MEMBER_REL:-}"
TENANCY_MEMBER_COLUMN="${TENANCY_MEMBER_COLUMN:-user_id}"
TENANCY_STATUS_FIELD="${TENANCY_STATUS_FIELD:-status}"
TENANCY_STATUS_VALUE="${TENANCY_STATUS_VALUE:-active}"

# Returns one of: user | tenant | hybrid | none
detect_scope() {
  local cols=",$1,"
  local has_user=0 has_tenant=0
  [[ "$cols" == *",user_id,"* ]] && has_user=1
  [[ -n "$TENANCY_COLUMN" && "$cols" == *",${TENANCY_COLUMN},"* ]] && has_tenant=1
  if [ $has_user = 1 ] && [ $has_tenant = 1 ]; then echo hybrid
  elif [ $has_user = 1 ]; then echo user
  elif [ $has_tenant = 1 ]; then echo tenant
  else echo none
  fi
}

# Emit the tenant-membership traversal filter (8-space indented body). Uses the
# discovered relationship names.
_tenant_filter_body() {
  cat <<YAML
          - ${TENANCY_REL}:
              ${TENANCY_MEMBER_REL}:
                _and:
                  - ${TENANCY_MEMBER_COLUMN}:
                      _eq: X-Hasura-User-Id
                  - ${TENANCY_STATUS_FIELD}:
                      _eq: ${TENANCY_STATUS_VALUE}
YAML
}

# Emit the YAML filter expression for the given scope. Indentation is 8 spaces
# (i.e. nested under a 6-space `filter:` / `check:` key).
emit_user_filter() {
  case "$1" in
    user)
      cat <<'YAML'
        _and:
          - user_id:
              _eq: X-Hasura-User-Id
          - deleted_at:
              _is_null: true
YAML
      ;;
    tenant)
      printf '        _and:\n'
      _tenant_filter_body
      cat <<'YAML'
          - deleted_at:
              _is_null: true
YAML
      ;;
    hybrid)
      printf '        _and:\n          - _or:\n'
      printf '              - user_id:\n                  _eq: X-Hasura-User-Id\n'
      _tenant_filter_body | sed 's/^          /              /'
      cat <<'YAML'
          - deleted_at:
              _is_null: true
YAML
      ;;
    none)
      cat <<'YAML'
        # TODO: define filter manually; no user_id or tenancy column detected.
        # Deny-by-default placeholder — REPLACE before applying to production.
        _and:
          - id:
              _eq: 00000000-0000-0000-0000-000000000000
YAML
      ;;
  esac
}

# Render YAML to stdout: format = regular | enum
emit_full_yaml() {
  local format="$1" scope="${2:-none}"
  if [ "$format" = "enum" ]; then
    cat <<'YAML'
is_enum: true
select_permissions:
  - role: user
    permission:
      columns: [value, description]
      filter: {}
      allow_aggregations: true
  - role: service
    permission:
      columns: [value, description]
      filter: {}
      allow_aggregations: true
  - role: anonymous
    permission:
      columns: [value, description]
      filter: {}
      allow_aggregations: true
YAML
    return
  fi

  local filter; filter="$(emit_user_filter "$scope")"
  # USER_INSERT_COLS and USER_SELECT_COLS are passed by the caller.
  local insert_cols select_cols
  insert_cols="$(_yaml_list "${USER_INSERT_COLS:-}")"
  select_cols="$(_yaml_list "${USER_SELECT_COLS:-}")"

  cat <<YAML
insert_permissions:
  - role: user
    permission:
      check:
$filter
      columns:
$insert_cols
  - role: service
    permission:
      check: {}
      columns:
$insert_cols
select_permissions:
  - role: user
    permission:
      columns:
$select_cols
      filter:
$filter
      allow_aggregations: true
  - role: service
    permission:
      columns:
$select_cols
      filter: {}
      allow_aggregations: true
update_permissions:
  - role: user
    permission:
      filter:
$filter
      check:
$filter
      columns:
$insert_cols
  - role: service
    permission:
      filter: {}
      check: {}
      columns:
$insert_cols
delete_permissions:
  - role: user
    permission:
      filter:
$filter
  - role: service
    permission:
      filter: {}
YAML
}

# Indent a comma-separated list as a YAML sequence at 8 spaces.
_yaml_list() {
  local s="$1"
  local IFS=','
  for item in $s; do
    printf '        - %s\n' "$item"
  done
}
