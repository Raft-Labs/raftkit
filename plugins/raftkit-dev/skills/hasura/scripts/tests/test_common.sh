#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/assert.sh"
source "$HERE/../lib/common.sh"

# now_ms returns 13-digit epoch ms
ts="$(now_ms)"
[[ "$ts" =~ ^[0-9]{13}$ ]] || { echo "  ✗ now_ms not 13 digits: $ts" >&2; exit 1; }

# slugify normalises arbitrary input to snake_case
assert_eq "create_meal_plans" "$(slugify 'Create Meal Plans')" "slugify spaces"
assert_eq "add_user_id_index"  "$(slugify 'Add user-id index')"  "slugify hyphens"
assert_eq "events_v2"          "$(slugify 'events v2!!')"        "slugify punctuation"

# latest_ts reads highest 13-digit prefix from a dir
tmp="$(mktemp -d)"
mkdir -p "$tmp/1700000000000_a" "$tmp/1800000000000_b" "$tmp/notatimestamp"
assert_eq "1800000000000" "$(latest_ts "$tmp")" "latest_ts picks max"

# race_safe_ts always strictly greater than latest
race="$(LATEST_TS_DIR="$tmp" race_safe_ts)"
(( race > 1800000000000 )) || { echo "  ✗ race_safe_ts not > latest: $race" >&2; exit 1; }
