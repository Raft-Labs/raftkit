#!/usr/bin/env bash
# Proves scripts/merge-settings.mjs is a real fail-closed merge, not a naive overwrite:
#   1. no existing file -> all managed keys written
#   2. existing unmanaged keys -> preserved byte-for-byte
#   3. existing enabledPlugins -> merged additively, nothing dropped
#   4. conflicting managed scalar -> nothing written, conflict reported (exit 2)
#   5. invalid JSON input -> nothing written, reason emitted (exit 1)
#   6. re-run with identical input -> byte-identical output, zero diff
#   7. wrong-shaped existing container (string/array where object/array expected) ->
#      conflict, never silently coerced (exit 2)
#   8. valid JSON with a non-object root ([]/string/null/number) -> rejected like
#      invalid JSON, never spread into a fresh settings object (exit 1)
set -uo pipefail
cd "$(dirname "$0")/.."
SCRIPT="plugins/raftkit-dev/skills/init/scripts/merge-settings.mjs"

failures=0
tmpdirs=()
cleanup() { for d in "${tmpdirs[@]:-}"; do [[ -n "$d" ]] && rm -rf "$d"; done; }
trap cleanup EXIT

check() { # <name> <expected: ok|fail> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected $expected, exit was $actual)"
    failures=$((failures + 1))
  fi
}

check_eq() { # <name> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (expected [$2], got [$3])"
    failures=$((failures + 1))
  fi
}

newtmp() { local d; d="$(mktemp -d)"; tmpdirs+=("$d"); echo "$d"; }

# 0. Target's parent directory does not exist yet (the real .claude/ case) -> created
d0="$(newtmp)"
target0="$d0/.claude/settings.json"
node "$SCRIPT" "$target0" >/dev/null 2>&1
check "nested parent dir: script exits ok" ok $?
[[ -f "$target0" ]]
check "nested parent dir: settings.json created under .claude/" ok $?

# 1. No existing file -> all managed keys written
d1="$(newtmp)"
target="$d1/settings.json"
node "$SCRIPT" "$target" >/dev/null 2>&1
check "fresh file: script exits ok" ok $?
[[ -f "$target" ]]
check "fresh file: settings.json created" ok $?
model_val="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).model)' "$target" 2>/dev/null)"
check_eq "fresh file: model set to opusplan" "opusplan" "$model_val"
rk_val="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(s.extraKnownMarketplaces.raftkit.source.repo)' "$target" 2>/dev/null)"
check_eq "fresh file: raftkit marketplace registered" "Raft-Labs/raftkit" "$rk_val"

# 2. Existing unmanaged keys preserved byte-for-byte
d2="$(newtmp)"
target2="$d2/settings.json"
cat > "$target2" <<'EOF'
{
  "someTeamSetting": {
    "nested": true,
    "value": 42
  },
  "statusLine": {
    "type": "command",
    "command": "bash ./my-statusline.sh"
  }
}
EOF
node "$SCRIPT" "$target2" >/dev/null 2>&1
check "unmanaged keys: script exits ok" ok $?
unmanaged_val="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(JSON.stringify(s.someTeamSetting))' "$target2" 2>/dev/null)"
check_eq "unmanaged keys: someTeamSetting untouched" '{"nested":true,"value":42}' "$unmanaged_val"
status_cmd="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(s.statusLine.command)' "$target2" 2>/dev/null)"
check_eq "unmanaged keys: statusLine untouched" "bash ./my-statusline.sh" "$status_cmd"

# 3. Existing enabledPlugins merged additively, nothing dropped
d3="$(newtmp)"
target3="$d3/settings.json"
cat > "$target3" <<'EOF'
{
  "enabledPlugins": {
    "some-other-plugin@some-marketplace": true
  }
}
EOF
node "$SCRIPT" "$target3" >/dev/null 2>&1
check "enabledPlugins merge: script exits ok" ok $?
other_present="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(!!s.enabledPlugins["some-other-plugin@some-marketplace"])' "$target3" 2>/dev/null)"
check_eq "enabledPlugins merge: pre-existing entry kept" "true" "$other_present"
core_present="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(!!s.enabledPlugins["raftkit-core@raftkit"])' "$target3" 2>/dev/null)"
check_eq "enabledPlugins merge: raftkit-core added" "true" "$core_present"

# 3b. Wrong-shaped existing values -> conflict, never silently coerced
#     (a string spread into {...str} or [...str] corrupts it into a char map/array)
assert_shape_conflict() { # <name> <fixture-json>
  local name="$1" fixture="$2"
  local d target before_hash exit_code after_hash out
  d="$(newtmp)"
  target="$d/settings.json"
  printf '%s' "$fixture" > "$target"
  before_hash="$(shasum "$target")"
  out="$(node "$SCRIPT" "$target" 2>&1)"
  exit_code=$?
  check "$name: exit code is exactly 2" ok $([[ $exit_code -eq 2 ]] && echo 0 || echo 1)
  after_hash="$(shasum "$target")"
  check_eq "$name: file left byte-identical" "$before_hash" "$after_hash"
}

assert_shape_conflict "wrong-shape permissions.allow (string)" '{"permissions": {"allow": "Bash(git status:*)"}}'
assert_shape_conflict "wrong-shape permissions (array)" '{"permissions": ["not", "an", "object"]}'
assert_shape_conflict "wrong-shape enabledPlugins (array)" '{"enabledPlugins": ["raftkit-core@raftkit"]}'
assert_shape_conflict "wrong-shape attribution (string)" '{"attribution": "none"}'
assert_shape_conflict "wrong-shape extraKnownMarketplaces (string)" '{"extraKnownMarketplaces": "none"}'

# 3c. Valid JSON whose ROOT isn't an object -> rejected like invalid JSON (exit 1),
#     never silently spread into a fresh settings object (that would discard the
#     original array/scalar root without a trace).
assert_root_rejected() { # <name> <fixture-json>
  local name="$1" fixture="$2"
  local d target before_content exit_code after_content out
  d="$(newtmp)"
  target="$d/settings.json"
  printf '%s' "$fixture" > "$target"
  before_content="$(cat "$target")"
  out="$(node "$SCRIPT" "$target" 2>&1)"
  exit_code=$?
  check_eq "$name: exit code is exactly 1" "1" "$exit_code"
  after_content="$(cat "$target")"
  check_eq "$name: file left untouched" "$before_content" "$after_content"
  [[ -n "$out" ]]
  check "$name: a reason is emitted" ok $?
}

assert_root_rejected "array root" '[]'
assert_root_rejected "string root" '"just a string"'
assert_root_rejected "null root" 'null'
assert_root_rejected "number root" '42'

# Specifically prove the corruption Codex flagged does not happen: a string
# permissions.allow must never become a per-character array in the output.
d3c="$(newtmp)"
target3c="$d3c/settings.json"
printf '%s' '{"permissions": {"allow": "Bash(git status:*)"}}' > "$target3c"
node "$SCRIPT" "$target3c" >/dev/null 2>&1
untouched_allow="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).permissions.allow)' "$target3c" 2>/dev/null)"
check_eq "wrong-shape permissions.allow: value never coerced into a char array" "Bash(git status:*)" "$untouched_allow"

# 4. Conflicting managed scalar -> nothing written, conflict reported
d4="$(newtmp)"
target4="$d4/settings.json"
cat > "$target4" <<'EOF'
{
  "model": "sonnet"
}
EOF
before_hash="$(shasum "$target4")"
node "$SCRIPT" "$target4" >/tmp/init-settings-conflict-out.$$ 2>&1
exit_code=$?
check "conflict: script exits non-zero" fail $exit_code
check_eq "conflict: exit code is exactly 2" "2" "$exit_code"
after_hash="$(shasum "$target4")"
check_eq "conflict: file left byte-identical" "$before_hash" "$after_hash"
grep -qi "model" /tmp/init-settings-conflict-out.$$
check "conflict: report names the conflicting key" ok $?
rm -f /tmp/init-settings-conflict-out.$$

# 5. Invalid JSON input -> nothing written, reason emitted
d5="$(newtmp)"
target5="$d5/settings.json"
echo '{ this is not json' > "$target5"
before_content="$(cat "$target5")"
node "$SCRIPT" "$target5" >/tmp/init-settings-invalid-out.$$ 2>&1
exit_code=$?
check "invalid JSON: script exits non-zero" fail $exit_code
check_eq "invalid JSON: exit code is exactly 1" "1" "$exit_code"
after_content="$(cat "$target5")"
check_eq "invalid JSON: file left untouched" "$before_content" "$after_content"
[[ -s /tmp/init-settings-invalid-out.$$ ]]
check "invalid JSON: a reason is emitted" ok $?
rm -f /tmp/init-settings-invalid-out.$$

# 6. Re-run with identical input -> byte-identical output, zero diff
d6="$(newtmp)"
target6="$d6/settings.json"
node "$SCRIPT" "$target6" >/dev/null 2>&1
first_hash="$(shasum "$target6")"
node "$SCRIPT" "$target6" >/dev/null 2>&1
check "idempotent re-run: script exits ok" ok $?
second_hash="$(shasum "$target6")"
check_eq "idempotent re-run: byte-identical output" "$first_hash" "$second_hash"

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
