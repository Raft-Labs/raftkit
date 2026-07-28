#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/dbml_grep.sh"

REPO_ROOT="$(find_repo_root)"
DBML="$REPO_ROOT/docs/schema.dbml"

usage() {
  cat <<EOF
check-schema.sh <subcommand> [args...]

Subcommands:
  refresh                       Run \`make create-dbml\`; fall back to cached on failure.
  has-table <name>              Exit 0 if table exists in DBML, 1 otherwise.
  has-column <table> <column>   Exit 0 if column exists, 1 otherwise.
  show-table <name>             Print the Table block for <name>.
EOF
}

cmd_refresh() {
  info "Refreshing docs/schema.dbml via 'make create-dbml'"
  if ( cd "$REPO_ROOT" && make create-dbml ) 2>/dev/null; then
    info "DBML refreshed."
    return 0
  fi
  warn "make create-dbml failed — falling back to cached docs/schema.dbml. \
Run 'make hasura-up stage=local' for a fresh snapshot."
  [ -f "$DBML" ] || die "No cached docs/schema.dbml found."
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    refresh)    cmd_refresh ;;
    has-table)  has_table   "$DBML" "$1" ;;
    has-column) has_column  "$DBML" "$1" "$2" ;;
    show-table) show_table  "$DBML" "$1" ;;
    -h|--help|"") usage ;;
    *) usage; die "unknown subcommand: $sub" ;;
  esac
}
main "$@"
