#!/usr/bin/env bash
# Runs every test_*.sh in this directory and summarises pass/fail.

set -u
cd "$(dirname "$0")"

declare -i pass=0 fail=0
for t in test_*.sh; do
  [ -f "$t" ] || continue
  printf '▸ %s\n' "$t"
  if bash "$t"; then
    pass+=1
  else
    fail+=1
    printf '  ✗ FAIL: %s\n' "$t" >&2
  fi
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
