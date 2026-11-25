#!/usr/bin/env bash
# Runs every *.test.sh in a directory (default: this one) in parallel, prints
# PASS or FAIL per suite with a failing suite's output, and exits 1 if any
# suite failed or none was found.
set -uo pipefail
dir="${1:-$(cd "$(dirname "$0")" && pwd)}"
[[ -d "$dir" ]] || { echo "run-all: no such directory: $dir" >&2; exit 2; }

suites=("$dir"/*.test.sh)
[[ -e "${suites[0]}" ]] || { echo "run-all: no *.test.sh in $dir" >&2; exit 1; }

logs="$(mktemp -d)"; trap 'rm -rf "$logs"' EXIT
pids=()
for t in "${suites[@]}"; do
  bash "$t" > "$logs/$(basename "$t").log" 2>&1 &
  pids+=("$!")
done

failed=0
for i in "${!suites[@]}"; do
  name="$(basename "${suites[$i]}")"
  if wait "${pids[$i]}"; then
    echo "PASS  $name"
  else
    echo "FAIL  $name"
    [[ -n "${GITHUB_ACTIONS:-}" ]] && echo "::group::$name output"
    cat "$logs/$name.log"
    [[ -n "${GITHUB_ACTIONS:-}" ]] && echo "::endgroup::"
    failed=$((failed + 1))
  fi
done

echo
if [[ "$failed" -gt 0 ]]; then
  echo "$failed of ${#suites[@]} suite(s) failed"
  exit 1
fi
echo "all ${#suites[@]} suites passed"
