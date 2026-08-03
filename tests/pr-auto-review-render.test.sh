#!/usr/bin/env bash
# Deterministic suite for pr-auto-review's renderer. Mirrors
# tests/setup-toolchain.test.sh's pattern: drive the shipped script directly
# over its shipped template, no test-only renderer.
set -uo pipefail
cd "$(dirname "$0")/.."

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

SKILL=plugins/raftkit-dev/skills/pr-auto-review
RENDER=$SKILL/scripts/render-pr-auto-review.mjs
TEMPLATE_DIR=$SKILL/references/assets

# S1 — happy path renders successfully with all valid inputs.
tmp1=$(mktemp -d); tmpdirs+=("$tmp1")
node "$RENDER" \
  --templates "$TEMPLATE_DIR" --out-dir "$tmp1" \
  --bot-name "RaftKit PR Auto-Review" --bot-email "pr-auto-review@raftlabs.com" \
  --timeout-minutes 15 --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
check "S1 happy-path renders" ok $?
[[ -f "$tmp1/pr-auto-review.yml" ]] || { echo "FAIL: S1 output file missing"; failures=$((failures+1)); }

# S2 — no unresolved __TOKEN__ placeholders remain in rendered output.
if [[ -f "$tmp1/pr-auto-review.yml" ]]; then
  if grep -qE '__[A-Z_]+__' "$tmp1/pr-auto-review.yml"; then
    echo "FAIL: S2 unresolved placeholder remains"; failures=$((failures+1))
  else
    echo "PASS: S2 no unresolved placeholders"
  fi
fi

# S3 — deterministic: identical inputs render byte-identical output.
tmp2=$(mktemp -d); tmpdirs+=("$tmp2")
node "$RENDER" \
  --templates "$TEMPLATE_DIR" --out-dir "$tmp2" \
  --bot-name "RaftKit PR Auto-Review" --bot-email "pr-auto-review@raftlabs.com" \
  --timeout-minutes 15 --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
if diff -q "$tmp1/pr-auto-review.yml" "$tmp2/pr-auto-review.yml" >/dev/null 2>&1; then
  echo "PASS: S3 byte-identical re-render"
else
  echo "FAIL: S3 re-render differs on unchanged input"; failures=$((failures+1))
fi

# S4 — bad bot email (injection-shaped) is rejected, renders nothing.
tmp4=$(mktemp -d); tmpdirs+=("$tmp4")
node "$RENDER" \
  --templates "$TEMPLATE_DIR" --out-dir "$tmp4" \
  --bot-name "x" --bot-email 'x$(rm -rf /)' \
  --timeout-minutes 15 --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
check "S4 injection-shaped email rejected" fail $?
[[ -f "$tmp4/pr-auto-review.yml" ]] && { echo "FAIL: S4 wrote a file despite validation failure"; failures=$((failures+1)); } || echo "PASS: S4 wrote nothing"

# S5 — non-numeric timeout-minutes is rejected.
tmp5=$(mktemp -d); tmpdirs+=("$tmp5")
node "$RENDER" \
  --templates "$TEMPLATE_DIR" --out-dir "$tmp5" \
  --bot-name "x" --bot-email "x@example.com" \
  --timeout-minutes "not-a-number" --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
check "S5 non-numeric timeout-minutes rejected" fail $?

# S6 — missing required flag exits with usage error (exit 2), not a crash.
tmp6=$(mktemp -d); tmpdirs+=("$tmp6")
node "$RENDER" --templates "$TEMPLATE_DIR" --out-dir "$tmp6" >/dev/null 2>&1
actual=$?
if [[ "$actual" -eq 2 ]]; then echo "PASS: S6 missing flags exit 2"; else echo "FAIL: S6 expected exit 2, got $actual"; failures=$((failures+1)); fi

# S7 — control/newline characters in bot-name are rejected.
tmp7=$(mktemp -d); tmpdirs+=("$tmp7")
node "$RENDER" \
  --templates "$TEMPLATE_DIR" --out-dir "$tmp7" \
  --bot-name "$(printf 'a\nb')" --bot-email "x@example.com" \
  --timeout-minutes 15 --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
check "S7 newline in bot-name rejected" fail $?

# S8 — rendered YAML is valid YAML (parse check, mirrors validate.yml's jq-for-JSON idea).
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  if [[ -f "$tmp1/pr-auto-review.yml" ]] && python3 -c "import yaml; yaml.safe_load(open('$tmp1/pr-auto-review.yml'))" 2>/dev/null; then
    echo "PASS: S8 rendered output is valid YAML"
  else
    echo "FAIL: S8 rendered output is not valid YAML"; failures=$((failures+1))
  fi
else
  echo "  (note: python3+PyYAML not available — S8 skipped, not failed)" >&2
fi

# S9 — a missing required template file fails closed (exit 3, clean
# message), never an unhandled crash (e.g. exit 1 with a raw stack trace).
tmp9templates=$(mktemp -d); tmpdirs+=("$tmp9templates")
cp "$TEMPLATE_DIR/pr-auto-review.yml" "$tmp9templates/"
# fix-loop-prompt.md deliberately absent from $tmp9templates.
tmp9out=$(mktemp -d); tmpdirs+=("$tmp9out")
node "$RENDER" \
  --templates "$tmp9templates" --out-dir "$tmp9out" \
  --bot-name "x" --bot-email "x@example.com" \
  --timeout-minutes 15 --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
actual=$?
if [[ "$actual" -eq 3 ]]; then echo "PASS: S9 missing template file exits 3"; else echo "FAIL: S9 expected exit 3, got $actual"; failures=$((failures+1)); fi
[[ -f "$tmp9out/pr-auto-review.yml" ]] && { echo "FAIL: S9 wrote a file despite missing template"; failures=$((failures+1)); } || echo "PASS: S9 wrote nothing"

# S10 — a stray __TOKEN__-shaped string inside fix-loop-prompt.md's own
# content is caught and rejected, never silently shipped into the rendered
# workflow (the substituted prompt content is the one place the generic
# unresolved-placeholder scan can't see into on its own).
tmp10templates=$(mktemp -d); tmpdirs+=("$tmp10templates")
cp "$TEMPLATE_DIR/pr-auto-review.yml" "$tmp10templates/"
printf 'Some prompt text.\n__NOT_A_REAL_TOKEN__\nMore prompt text.\n' > "$tmp10templates/fix-loop-prompt.md"
tmp10out=$(mktemp -d); tmpdirs+=("$tmp10out")
node "$RENDER" \
  --templates "$tmp10templates" --out-dir "$tmp10out" \
  --bot-name "x" --bot-email "x@example.com" \
  --timeout-minutes 15 --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
actual=$?
if [[ "$actual" -eq 3 ]]; then echo "PASS: S10 stray placeholder in prompt content rejected"; else echo "FAIL: S10 expected exit 3, got $actual"; failures=$((failures+1)); fi
[[ -f "$tmp10out/pr-auto-review.yml" ]] && { echo "FAIL: S10 wrote a file despite stray placeholder"; failures=$((failures+1)); } || echo "PASS: S10 wrote nothing"

echo "----"
if [[ "$failures" -eq 0 ]]; then
  echo "OK: all pr-auto-review render checks passed"
else
  echo "FAIL: $failures check(s) failed"
  exit 1
fi
