# Shared bash utilities for the hasura skill. Source, do not execute.

# The project root — prefer git (a Hasura project is not obliged to have a
# Makefile at its root); fall back to walking up for a Makefile only when git
# is unavailable or this isn't a git repo.
find_repo_root() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" && { printf '%s' "$root"; return; }
  local d="$PWD"
  while [ "$d" != "/" ]; do
    [ -f "$d/Makefile" ] && { printf '%s' "$d"; return; }
    d="$(dirname "$d")"
  done
  die "Could not find a project root (no git repo and no Makefile found above $PWD)."
}

# The Hasura project directory — DISCOVERED, never assumed to be
# services/hasura. Priority: an explicit $HASURA_ROOT override > a
# config.yaml at the repo root or one level down (the same signal
# detect-hasura.mjs uses) > services/hasura or hasura/, kept last for exact
# compatibility with repos shaped like the project this skill was ported from.
find_hasura_root() {
  local repo_root="$1"
  if [ -n "${HASURA_ROOT:-}" ]; then printf '%s' "$HASURA_ROOT"; return; fi
  [ -f "$repo_root/config.yaml" ] && { printf '%s' "$repo_root"; return; }
  local d
  for d in "$repo_root"/*/ "$repo_root"/*/*/; do
    [ -f "${d}config.yaml" ] && { printf '%s' "${d%/}"; return; }
  done
  [ -d "$repo_root/services/hasura" ] && { printf '%s' "$repo_root/services/hasura"; return; }
  [ -d "$repo_root/hasura" ] && { printf '%s' "$repo_root/hasura"; return; }
  die "Could not find a Hasura project directory under $repo_root (looked for config.yaml, services/hasura/, hasura/; set HASURA_ROOT to override)."
}

# Print epoch milliseconds as a 13-digit integer.
# Portable across macOS (BSD date), Linux (GNU date), and as last resort python3.
now_ms() {
  local ms
  ms="$(date +%s%3N 2>/dev/null || true)"
  if [[ "$ms" =~ ^[0-9]{13}$ ]]; then printf '%s' "$ms"; return; fi
  if command -v gdate >/dev/null 2>&1; then
    gdate +%s%3N; return
  fi
  python3 -c 'import time; print(int(time.time()*1000))'
}

# Normalise free-form input into snake_case suitable for migration slugs.
slugify() {
  local s="$1"
  s="${s,,}"                     # lowercase
  s="${s//[^a-z0-9]/_}"          # non-alnum → underscore
  s="$(printf '%s' "$s" | tr -s '_')"   # collapse repeats
  s="${s#_}"; s="${s%_}"         # trim edges
  printf '%s' "$s"
}

# Highest 13-digit timestamp prefix found in the given migrations directory.
# Prints nothing if none.
latest_ts() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  ls "$dir" 2>/dev/null \
    | grep -Eo '^[0-9]{13}' \
    | sort -n \
    | tail -1
}

# Race-safe migration timestamp: max(now_ms, latest_ts + 1).
# Respects $LATEST_TS_DIR env (set by callers / tests) or defaults to the repo
# migrations dir.
race_safe_ts() {
  local dir="${LATEST_TS_DIR:-services/hasura/migrations/default}"
  local latest now
  latest="$(latest_ts "$dir")"
  now="$(now_ms)"
  if [ -n "$latest" ] && [ "$latest" -ge "$now" ]; then
    printf '%s' "$((latest + 1))"
  else
    printf '%s' "$now"
  fi
}

# Logging helpers (no colour to keep grep-friendly).
info() { printf '▸ %s\n' "$*"; }
warn() { printf '⚠ %s\n' "$*" >&2; }
err()  { printf '✗ %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }
