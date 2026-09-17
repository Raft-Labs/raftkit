#!/usr/bin/env bash
# Behavioural suite for the docs companion renderer (raftkit-docs). Drives the
# shipped render-companion.mjs over its shipped source: valid frontmatter is
# preserved, a bad source renders nothing.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

failures=0
check() {
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected $expected, exit was $actual)"
    failures=$((failures + 1))
  fi
}

RENDER=plugins/raftkit-docs/skills/docs-product/scripts/render-companion.mjs
SRC=plugins/raftkit-docs/skills/docs-product/assets/companion/SKILL.md

[[ -f "$RENDER" && -f "$SRC" ]]
check "C1 the renderer and its companion source both ship" ok $?

node --check "$RENDER"
check "C2 the renderer is syntactically valid" ok $?

d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
node "$RENDER" --source "$SRC" --out "$d/SKILL.md" >/dev/null 2>&1
rc=$?
if [[ $rc -eq 0 && -f "$d/SKILL.md" ]]; then
  grep -q '^name:' "$d/SKILL.md" && grep -q '^description:' "$d/SKILL.md"
  check "C3 a rendered companion keeps its name and description" ok $?
else
  check "C3 a rendered companion keeps its name and description" ok 1
fi

printf 'no frontmatter here\n' > "$d/bad.md"
node "$RENDER" --source "$d/bad.md" --out "$d/never.md" >/dev/null 2>&1
check "C4 a source without frontmatter renders nothing (fail-closed)" fail $?
[[ ! -f "$d/never.md" ]]
check "C5 nothing was written on the failed render" ok $?

echo
[[ "$failures" -eq 0 ]]
