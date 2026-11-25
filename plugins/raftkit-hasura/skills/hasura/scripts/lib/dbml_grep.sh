# DBML collision helpers. Source, do not execute.
#
# db2dbml emits public-schema tables in either of two forms:
#   Table "events" { ... }                # bare form (used by the version installed in this repo)
#   Table "public"."events" { ... }       # dotted form (some db2dbml versions / non-public schemas)
# The helpers below match either form for the public schema, but never match
# tables in other schemas (e.g. hdb_catalog) when called with a bare name.

has_table() {
  local dbml="$1" table="$2"
  [ -f "$dbml" ] || return 2
  grep -qE "^Table (\"public\"\\.)?\"${table}\" \\{" "$dbml"
}

# Extract the body of Table "<name>" { ... } (or Table "public"."<name>" { ... })
# up to the matching `}`.
show_table() {
  local dbml="$1" table="$2"
  [ -f "$dbml" ] || return 2
  awk -v t="$table" '
    match($0, "^Table (\"public\"\\.)?\"" t "\" \\{") { in_block=1 }
    in_block { print }
    in_block && /^}/ { in_block=0; exit }
  ' "$dbml"
}

has_column() {
  local dbml="$1" table="$2" col="$3"
  [ -f "$dbml" ] || return 2
  show_table "$dbml" "$table" | grep -q "^  \"${col}\" "
}
