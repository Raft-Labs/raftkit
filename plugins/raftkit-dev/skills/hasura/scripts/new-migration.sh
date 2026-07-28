#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/render.sh"
source "$SCRIPT_DIR/lib/fk_parse.sh"
source "$SCRIPT_DIR/lib/perms.sh"
source "$SCRIPT_DIR/lib/dbml_grep.sh"

# Resolve repo root and the discovered Hasura project directory (see
# lib/common.sh — never hardcoded to services/hasura; HASURA_ROOT,
# HASURA_MIGRATIONS_SUBDIR, HASURA_METADATA_SUBDIR override the discovered
# defaults when a project's layout needs it).
REPO_ROOT="$(find_repo_root)"
HASURA_DIR="$(find_hasura_root "$REPO_ROOT")"
MIGRATIONS_DIR="$HASURA_DIR/${HASURA_MIGRATIONS_SUBDIR:-migrations/default}"
METADATA_DIR="$HASURA_DIR/${HASURA_METADATA_SUBDIR:-metadata/databases/default/tables}"
DBML="$REPO_ROOT/docs/schema.dbml"
LATEST_TS_DIR="$MIGRATIONS_DIR"; export LATEST_TS_DIR

usage() {
  cat <<EOF
new-migration.sh <subcommand> [args...]

Subcommands (DDL-emitting subcommands run a DBML refresh + collision check first):
  create-table       <name> [--col SPEC]... [--scope user|tenant|hybrid|none]
  create-enum-table  <name> [--values "a,b,c"]
  add-column         <table> <col> <type> [--not-null] [--default <expr>] [--fk <ref>]
  drop-column        <table> <col>
  add-index          <table> <cols> [--unique] [--partial "<where>"]
  rename             column|table <from> <to> [--table <t>]
  function-trigger   <slug>
  permission-only    <slug>

Column SPEC: name:type[:not_null][:default=<expr>][:fk=<table>.<col>]

Env vars:
  HASURA_SKILL_AUTOCONFIRM=1   Skip the "Write these files?" prompt (used by tests).
EOF
}

refresh_dbml() {
  info "Refreshing docs/schema.dbml (make create-dbml)…"
  if ! ( cd "$REPO_ROOT" && make create-dbml ) >/dev/null 2>&1; then
    warn "make create-dbml failed — using cached docs/schema.dbml. Run 'make hasura-up stage=local' first for a fresh snapshot."
    [ -f "$DBML" ] || die "No cached docs/schema.dbml found."
  fi
}

confirm_write() {
  local prompt="$1"
  if [ "${HASURA_SKILL_AUTOCONFIRM:-0}" = 1 ]; then return 0; fi
  printf '\n%s [y/N] ' "$prompt"
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]] || die "Aborted."
}

write_migration() {
  local slug="$1" up="$2" down="$3"
  [ -n "$slug" ] || die "write_migration: empty slug"
  local ts; ts="$(race_safe_ts)"
  local dir="$MIGRATIONS_DIR/${ts}_${slug}"
  mkdir -p "$dir"
  printf '%s\n' "$up"   > "$dir/up.sql"
  printf '%s\n' "$down" > "$dir/down.sql"
  info "Wrote $dir/{up,down}.sql"
  printf '%s' "$dir"
}

print_followup() {
  local table="${1:-}"
  cat <<'EOF'

Next steps:
  1. make hasura-migrate stage=local
  2. make create-dbml                       # refresh docs/schema.dbml AFTER applying
  3. Commit the migration files, the metadata YAML (if any), AND the refreshed
     docs/schema.dbml together:
       git add services/hasura/migrations/default/<ts>_<slug>/ \\
EOF
  if [ -n "$table" ]; then
    printf '               services/hasura/metadata/databases/default/tables/public_%s.yaml \\\n' "$table"
  fi
  cat <<'EOF'
               docs/schema.dbml
       git commit -m "feat(hasura): <message>"
EOF
}

# --- create-table ---------------------------------------------------------
cmd_create_table() {
  local name="" scope=""
  declare -a col_specs=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --col)   col_specs+=("$2"); shift 2 ;;
      --scope) scope="$2"; shift 2 ;;
      --) shift; break ;;
      -*) die "unknown flag: $1" ;;
      *) [ -z "$name" ] && name="$1" || die "extra positional: $1"; shift ;;
    esac
  done
  [ -n "$name" ] || die "create-table: missing <name>"
  name="$(slugify "$name")"
  [ -n "$name" ] || die "name resolved to empty slug; use letters/numbers/underscores"

  refresh_dbml
  if has_table "$DBML" "$name"; then
    show_table "$DBML" "$name"
    die "Table public.$name already exists. Use add-column / rename instead."
  fi

  # Build COLUMNS_SQL, INDEXES_SQL, OBJECT_RELATIONSHIPS_YAML, scope-detection list.
  local cols_sql="" indexes_sql="" rels_yaml="" col_names="id"
  local rels_count=0
  for spec in "${col_specs[@]:-}"; do
    [ -z "$spec" ] && continue
    eval "$(parse_col "$spec")"
    local null_clause=""; [ "$COL_NOT_NULL" = 1 ] && null_clause=" NOT NULL"
    local default_clause=""; [ -n "$COL_DEFAULT" ] && default_clause=" DEFAULT $COL_DEFAULT"
    local fk_clause=""
    if [ -n "$COL_FK_TABLE" ]; then
      fk_clause=" REFERENCES public.${COL_FK_TABLE}(${COL_FK_COL})"
      indexes_sql+="CREATE INDEX idx_${name}_${COL_NAME} ON public.${name}(${COL_NAME});"$'\n'
      local rel; rel="$(rel_name_object "$COL_NAME" "$COL_FK_TABLE")"
      if [ $rels_count -eq 0 ]; then
        rels_yaml+="object_relationships:"$'\n'
      fi
      rels_yaml+="  - name: ${rel}"$'\n'
      rels_yaml+="    using:"$'\n'
      rels_yaml+="      foreign_key_constraint_on: ${COL_NAME}"$'\n'
      rels_count=$((rels_count + 1))
    fi
    cols_sql+="  ${COL_NAME} ${COL_TYPE}${null_clause}${default_clause}${fk_clause},"$'\n'
    col_names+=",${COL_NAME}"
  done
  col_names+=",created_at,updated_at,deleted_at"
  [ -z "$rels_yaml" ] && rels_yaml="object_relationships: []"

  if [ -z "$scope" ]; then scope="$(detect_scope "$col_names")"; fi

  # Compute permission column lists.
  local user_insert_cols user_select_cols
  user_select_cols="$col_names"
  user_insert_cols="$(printf '%s' "$col_names" \
    | tr ',' '\n' | grep -Ev '^(id|created_at|updated_at|deleted_at)$' | paste -sd, -)"

  local perm_yaml
  perm_yaml="$(USER_INSERT_COLS="$user_insert_cols" USER_SELECT_COLS="$user_select_cols" \
    emit_full_yaml regular "$scope")"

  local up down yaml
  up="$(TABLE="$name" COLUMNS_SQL="$cols_sql" INDEXES_SQL="$indexes_sql" \
        render "$SCRIPT_DIR/../templates/create-table.up.sql.tmpl")"
  down="$(TABLE="$name" render "$SCRIPT_DIR/../templates/create-table.down.sql.tmpl")"
  yaml="$(TABLE="$name" OBJECT_RELATIONSHIPS_YAML="$rels_yaml" PERMISSIONS_YAML="$perm_yaml" \
        render "$SCRIPT_DIR/../templates/create-table.yaml.tmpl")"

  printf '\n=== Proposed up.sql ===\n%s\n' "$up"
  printf '\n=== Proposed down.sql ===\n%s\n' "$down"
  printf '\n=== Proposed public_%s.yaml ===\n%s\n' "$name" "$yaml"
  confirm_write "Write these files?"

  local dir; dir="$(write_migration "create_${name}" "$up" "$down")"
  printf '%s\n' "$yaml" > "$METADATA_DIR/public_${name}.yaml"
  info "Wrote $METADATA_DIR/public_${name}.yaml"
  print_followup "$name"
}

# --- create-enum-table ---------------------------------------------------
cmd_create_enum_table() {
  local name="" values=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --values) values="$2"; shift 2 ;;
      -*) die "unknown flag: $1" ;;
      *) [ -z "$name" ] && name="$1" || die "extra positional: $1"; shift ;;
    esac
  done
  [ -n "$name" ] || die "create-enum-table: missing <name>"
  name="$(slugify "$name")"
  [ -n "$name" ] || die "name resolved to empty slug; use letters/numbers/underscores"
  refresh_dbml
  if has_table "$DBML" "$name"; then
    die "Enum public.$name already exists."
  fi

  local inserts_sql=""
  if [ -n "$values" ]; then
    inserts_sql="INSERT INTO public.${name} (value, description) VALUES"$'\n'
    local first=1 v
    # Split on commas without touching the function-level IFS (which `render` relies on).
    local -a vals
    IFS=',' read -ra vals <<<"$values"
    for v in "${vals[@]}"; do
      v="$(printf '%s' "$v" | sed 's/^ *//;s/ *$//')"
      [ -z "$v" ] && continue
      [ $first = 1 ] || inserts_sql+=","$'\n'
      inserts_sql+="  ('${v}', NULL)"
      first=0
    done
    inserts_sql+=";"$'\n'
  fi

  local up down yaml
  up="$(TABLE="$name" INSERT_VALUES_SQL="$inserts_sql" \
        render "$SCRIPT_DIR/../templates/create-enum-table.up.sql.tmpl")"
  down="$(TABLE="$name" render "$SCRIPT_DIR/../templates/create-enum-table.down.sql.tmpl")"
  yaml="$(TABLE="$name" render "$SCRIPT_DIR/../templates/create-enum-table.yaml.tmpl")"

  printf '\n=== Proposed up.sql ===\n%s\n' "$up"
  printf '\n=== Proposed down.sql ===\n%s\n' "$down"
  printf '\n=== Proposed public_%s.yaml ===\n%s\n' "$name" "$yaml"
  confirm_write "Write these files?"

  local dir; dir="$(write_migration "create_${name}_enum" "$up" "$down")"
  printf '%s\n' "$yaml" > "$METADATA_DIR/public_${name}.yaml"
  info "Wrote $METADATA_DIR/public_${name}.yaml"
  print_followup "$name"
}

# --- add-column -----------------------------------------------------------
cmd_add_column() {
  local table="$1" col="$2" type="$3"; shift 3
  local not_null=0 default="" fk=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --not-null) not_null=1; shift ;;
      --default)  default="$2"; shift 2 ;;
      --fk)       fk="$2"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  refresh_dbml
  has_table "$DBML" "$table" || die "Table public.$table not found in DBML."
  if has_column "$DBML" "$table" "$col"; then
    die "Column $table.$col already exists."
  fi
  local null_clause=""; [ $not_null = 1 ] && null_clause=" NOT NULL"
  local default_clause=""; [ -n "$default" ] && default_clause=" DEFAULT $default"
  local fk_clause=""
  if [ -n "$fk" ]; then
    fk_clause=" REFERENCES public.${fk%%.*}(${fk#*.})"
  fi
  local up down
  up="$(TABLE="$table" COLUMN="$col" TYPE="$type" \
        NOT_NULL_CLAUSE="$null_clause" DEFAULT_CLAUSE="$default_clause" FK_CLAUSE="$fk_clause" \
        render "$SCRIPT_DIR/../templates/add-column.up.sql.tmpl")"
  down="$(TABLE="$table" COLUMN="$col" render "$SCRIPT_DIR/../templates/add-column.down.sql.tmpl")"
  printf '\n=== Proposed up.sql ===\n%s\n' "$up"
  printf '\n=== Proposed down.sql ===\n%s\n' "$down"
  confirm_write "Write these files?"
  write_migration "add_${col}_to_${table}" "$up" "$down" >/dev/null
  print_followup "$table"
}

# --- drop-column ----------------------------------------------------------
cmd_drop_column() {
  local table="$1" col="$2"
  refresh_dbml
  has_column "$DBML" "$table" "$col" || die "Column $table.$col not found."
  warn "DROP COLUMN is destructive — verify the column is unused first."
  local up down
  up="$(TABLE="$table" COLUMN="$col"  render "$SCRIPT_DIR/../templates/drop-column.up.sql.tmpl")"
  down="$(TABLE="$table" COLUMN="$col" render "$SCRIPT_DIR/../templates/drop-column.down.sql.tmpl")"
  printf '\n=== Proposed up.sql ===\n%s\n' "$up"
  printf '\n=== Proposed down.sql ===\n%s\n' "$down"
  confirm_write "Write these files?"
  write_migration "drop_${col}_from_${table}" "$up" "$down" >/dev/null
  print_followup "$table"
}

# --- add-index ------------------------------------------------------------
cmd_add_index() {
  local table="$1" cols="$2"; shift 2
  local unique=0 partial=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --unique)  unique=1; shift ;;
      --partial) partial="$2"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  refresh_dbml
  has_table "$DBML" "$table" || die "Table public.$table not found."
  local idx_suffix; idx_suffix="$(printf '%s' "$cols" | tr -d ' ' | tr ',' '_')"
  local idx_name="idx_${table}_${idx_suffix}"
  local unique_clause=""; [ $unique = 1 ] && unique_clause="UNIQUE "
  local partial_clause=""; [ -n "$partial" ] && partial_clause=" WHERE $partial"
  local up down
  up="$(TABLE="$table" IDX_COLUMNS="$cols" INDEX_NAME="$idx_name" \
        UNIQUE_CLAUSE="$unique_clause" PARTIAL_CLAUSE="$partial_clause" \
        render "$SCRIPT_DIR/../templates/add-index.up.sql.tmpl")"
  down="$(INDEX_NAME="$idx_name" render "$SCRIPT_DIR/../templates/add-index.down.sql.tmpl")"
  printf '\n=== Proposed up.sql ===\n%s\n' "$up"
  printf '\n=== Proposed down.sql ===\n%s\n' "$down"
  confirm_write "Write these files?"
  write_migration "index_${table}_${idx_suffix}" "$up" "$down" >/dev/null
  print_followup "$table"
}

# --- rename ---------------------------------------------------------------
cmd_rename() {
  local kind="$1" from="$2" to="$3"; shift 3
  local table=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --table) table="$2"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  refresh_dbml
  case "$kind" in
    table)
      has_table "$DBML" "$from" || die "Source table $from not found."
      ! has_table "$DBML" "$to" || die "Target table $to already exists."
      local up down
      up="$(FROM="$from" TO="$to" render "$SCRIPT_DIR/../templates/rename-table.up.sql.tmpl")"
      down="$(FROM="$from" TO="$to" render "$SCRIPT_DIR/../templates/rename-table.down.sql.tmpl")"
      printf '\n=== Proposed up.sql ===\n%s\n' "$up"
      printf '\n=== Proposed down.sql ===\n%s\n' "$down"
      confirm_write "Write these files?"
      write_migration "rename_${from}_to_${to}" "$up" "$down" >/dev/null
      print_followup "$to"
      ;;
    column)
      [ -n "$table" ] || die "rename column needs --table <name>"
      has_column "$DBML" "$table" "$from" || die "Column $table.$from not found."
      ! has_column "$DBML" "$table" "$to" || die "Target $table.$to already exists."
      local up down
      up="$(TABLE="$table" FROM="$from" TO="$to" render "$SCRIPT_DIR/../templates/rename-column.up.sql.tmpl")"
      down="$(TABLE="$table" FROM="$from" TO="$to" render "$SCRIPT_DIR/../templates/rename-column.down.sql.tmpl")"
      printf '\n=== Proposed up.sql ===\n%s\n' "$up"
      printf '\n=== Proposed down.sql ===\n%s\n' "$down"
      confirm_write "Write these files?"
      write_migration "rename_${table}_${from}_to_${to}" "$up" "$down" >/dev/null
      print_followup "$table"
      ;;
    *) die "rename: kind must be 'table' or 'column'" ;;
  esac
}

# --- function-trigger -----------------------------------------------------
cmd_function_trigger() {
  local slug; slug="$(slugify "$1")"
  [ -n "$slug" ] || die "slug resolved to empty; use letters/numbers/underscores"
  local up down
  up="$(SLUG="$slug" render "$SCRIPT_DIR/../templates/function-trigger.up.sql.tmpl")"
  down="$(SLUG="$slug" render "$SCRIPT_DIR/../templates/function-trigger.down.sql.tmpl")"
  printf '\n=== Proposed up.sql ===\n%s\n' "$up"
  printf '\n=== Proposed down.sql ===\n%s\n' "$down"
  confirm_write "Write empty function/trigger scaffold?"
  write_migration "$slug" "$up" "$down" >/dev/null
  print_followup ""
}

# --- permission-only ------------------------------------------------------
cmd_permission_only() {
  local slug; slug="$(slugify "$1")"
  [ -n "$slug" ] || die "slug resolved to empty; use letters/numbers/underscores"
  local up down
  up="$(render "$SCRIPT_DIR/../templates/permission-only.up.sql.tmpl")"
  down="-- No-op down for permission-only change.
SELECT 1;
"
  printf '\n=== Proposed up.sql ===\n%s\n' "$up"
  printf '\n=== Proposed down.sql ===\n%s\n' "$down"
  confirm_write "Write permission-only scaffold?"
  write_migration "$slug" "$up" "$down" >/dev/null
  print_followup ""
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    create-table)       cmd_create_table       "$@" ;;
    create-enum-table)  cmd_create_enum_table  "$@" ;;
    add-column)         cmd_add_column         "$@" ;;
    drop-column)        cmd_drop_column        "$@" ;;
    add-index)          cmd_add_index          "$@" ;;
    rename)             cmd_rename             "$@" ;;
    function-trigger)   cmd_function_trigger   "$@" ;;
    permission-only)    cmd_permission_only    "$@" ;;
    -h|--help|"")       usage ;;
    *) usage; die "unknown subcommand: $sub" ;;
  esac
}
main "$@"
