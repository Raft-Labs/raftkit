#!/usr/bin/env bash
# Tiny assertion helpers for hasura skill tests. Each helper aborts the test
# script (exit 1) on failure so the harness sees a non-zero exit.

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [ "$expected" != "$actual" ]; then
    printf '  ✗ assert_eq failed: %s\n      expected: %q\n      actual:   %q\n' \
      "$msg" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf '  ✗ assert_contains failed: %s\n      needle: %q\n      in:     %q\n' \
      "$msg" "$needle" "$haystack" >&2
    exit 1
  fi
}

assert_exit_code() {
  local expected="$1"; shift
  local msg="$1"; shift
  "$@" >/dev/null 2>&1
  local actual=$?
  if [ "$expected" != "$actual" ]; then
    printf '  ✗ assert_exit_code failed: %s\n      expected exit: %s\n      actual:        %s\n' \
      "$msg" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_file_exists() {
  if [ ! -f "$1" ]; then
    printf '  ✗ assert_file_exists failed: %s\n' "$1" >&2
    exit 1
  fi
}
