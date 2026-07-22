# Column-flag parsing and relationship-name derivation. Source, do not execute.

# Parse a --col spec into eval-friendly assignments.
#   name:type[:not_null][:default=<expr>][:fk=<table>.<col>]
# Emits: COL_NAME, COL_TYPE, COL_NOT_NULL (0/1), COL_DEFAULT,
#        COL_FK_TABLE, COL_FK_COL.
parse_col() {
  local spec="$1"
  local name type
  IFS=':' read -r name type _ <<<"$spec"
  local tail="${spec#${name}:${type}}"
  tail="${tail#:}"

  local not_null=0 default="" fk_table="" fk_col=""
  if [ -n "$tail" ]; then
    local IFS=':'
    for tok in $tail; do
      case "$tok" in
        not_null) not_null=1 ;;
        default=*) default="${tok#default=}" ;;
        fk=*)
          local target="${tok#fk=}"
          fk_table="${target%%.*}"
          fk_col="${target#*.}"
          ;;
      esac
    done
  fi

  printf 'COL_NAME=%q\nCOL_TYPE=%q\nCOL_NOT_NULL=%q\nCOL_DEFAULT=%q\nCOL_FK_TABLE=%q\nCOL_FK_COL=%q\n' \
    "$name" "$type" "$not_null" "$default" "$fk_table" "$fk_col"
}

# Convert snake_case to camelCase.
_camel() {
  local s="$1" out="" first=1
  local IFS='_'
  for part in $s; do
    [ -z "$part" ] && continue
    if [ "$first" = 1 ]; then
      out+="$part"; first=0
    else
      out+="$(printf '%s' "${part:0:1}" | tr '[:lower:]' '[:upper:]')${part:1}"
    fi
  done
  printf '%s' "$out"
}

# Object relationship name from FK column + target table.
# Signatures:
#   rel_name_object <fk_col> <target_table>                          # regular table FK
#   rel_name_object <fk_col> <enum_target_table> <owning_table>      # enum FK
#
# Rules (verify against the project's existing Hasura metadata):
# - If owning_table is provided → target is an enum table; rel name is the
#   target enum table camelCased (the owning_table arg is currently unused
#   but accepted for signature stability and future special cases).
# - Otherwise (regular table FK):
#     * If target = "users" and fk_col ends with "_by" (e.g., created_by),
#       append "_user": created_by → createdByUser, updated_by → updatedByUser.
#     * Otherwise drop the "_id" suffix and camelCase: org_id → org,
#       parent_event_id → parentEvent.
rel_name_object() {
  local fk="$1" target="$2" owning="${3:-}"
  local base

  if [ -n "$owning" ]; then
    # Enum FK: rel name is camelCase of the enum target table itself.
    base="$target"
  else
    if [ "$target" = "users" ] && [[ "$fk" == *_by ]]; then
      base="${fk}_user"
    else
      base="${fk%_id}"
    fi
  fi
  _camel "$base"
}

# Array relationship name from referencing table (snake_case → camelCase).
rel_name_array() {
  _camel "$1"
}
