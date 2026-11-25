#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(find_repo_root)"
HASURA_DIR="$(find_hasura_root "$REPO_ROOT")"

usage() {
  cat <<EOF
hasura-query.sh --stage=<local|development|production> [options] [<query-file>|-]

Options:
  --role=<role>           admin (default) | user | service | anonymous
  --user-id=<uuid>        Sent as X-Hasura-User-Id when --role is non-admin.
  --family-id=<uuid>      Sent as X-Hasura-Family-Id (optional).
  --variables='<json>'    GraphQL variables JSON object.
  --raw                   Skip jq pretty-print.

Reads HASURA_GRAPHQL_ENDPOINT + HASURA_GRAPHQL_ADMIN_SECRET from the
discovered Hasura directory's console/.env.<stage> (HASURA_ROOT overrides the
discovered directory). If that file does not exist, run:
  make hasura-env stage=<stage>
EOF
}

main() {
  local stage="" role="admin" user_id="" family_id="" variables="{}" raw=0
  local query_file=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --stage=*)     stage="${1#--stage=}"; shift ;;
      --role=*)      role="${1#--role=}"; shift ;;
      --user-id=*)   user_id="${1#--user-id=}"; shift ;;
      --family-id=*) family_id="${1#--family-id=}"; shift ;;
      --variables=*) variables="${1#--variables=}"; shift ;;
      --raw)         raw=1; shift ;;
      -h|--help)     usage; return 0 ;;
      -)             query_file=-; shift ;;
      *)             query_file="$1"; shift ;;
    esac
  done
  [ -n "$stage" ] || { usage; die "--stage required"; }

  local env_file="$HASURA_DIR/console/.env.$stage"
  if [ ! -f "$env_file" ]; then
    die "Missing $env_file
Run: make hasura-env stage=$stage"
  fi

  # Source carefully — do not log the secret.
  set -a; source "$env_file"; set +a
  : "${HASURA_GRAPHQL_ENDPOINT:?endpoint missing in $env_file}"
  : "${HASURA_GRAPHQL_ADMIN_SECRET:?admin secret missing in $env_file}"

  local query=""
  if [ -z "$query_file" ]; then
    die "No query provided. Pass a file path or '-' to read from stdin."
  elif [ "$query_file" = "-" ]; then
    query="$(cat)"
  else
    [ -f "$query_file" ] || die "query file not found: $query_file"
    query="$(cat "$query_file")"
  fi

  # Build JSON payload safely with jq if available; else fall back to python3.
  local payload
  if command -v jq >/dev/null 2>&1; then
    payload="$(jq -n --arg q "$query" --argjson v "$variables" \
                '{query:$q,variables:$v}')"
  else
    payload="$(python3 -c '
import json, sys
q = sys.argv[1]
v = json.loads(sys.argv[2])
print(json.dumps({"query": q, "variables": v}))
' "$query" "$variables")"
  fi

  # The admin secret never reaches curl's argv (visible to other local users
  # via ps/proc while the process runs) — it goes in a 600-permission curl
  # config file instead, cleaned up on exit. The payload also goes through a
  # file, not -d on the command line, for the same reason.
  local curlcfg payloadfile
  curlcfg="$(mktemp)"; payloadfile="$(mktemp)"
  trap 'rm -f "$curlcfg" "$payloadfile"' RETURN
  chmod 600 "$curlcfg"
  {
    printf 'header = "Content-Type: application/json"\n'
    printf 'header = "x-hasura-admin-secret: %s"\n' "$HASURA_GRAPHQL_ADMIN_SECRET"
    if [ "$role" != "admin" ]; then
      printf 'header = "X-Hasura-Role: %s"\n' "$role"
      [ -n "$user_id" ]   && printf 'header = "X-Hasura-User-Id: %s"\n' "$user_id"
      [ -n "$family_id" ] && printf 'header = "X-Hasura-Family-Id: %s"\n' "$family_id"
    fi
  } > "$curlcfg"
  printf '%s' "$payload" > "$payloadfile"

  local response
  response="$(curl -sS -X POST -K "$curlcfg" -d "@$payloadfile" "$HASURA_GRAPHQL_ENDPOINT")"

  if [ $raw = 1 ] || ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' "$response"
  else
    printf '%s' "$response" | jq .
  fi
}
main "$@"
