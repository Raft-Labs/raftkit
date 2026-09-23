#!/usr/bin/env bash
# Contracts of the raftkit-dev story and bug flow (implement, fix, scope-guard,
# docs, the verifier agent) that another component, the platform, or a live
# template depends on. Each check pins an interface — a string another
# component reads, a path two skills must agree on, a model a dispatch passes —
# never wording for its own sake. Mutation-checked when added.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

failures=0
check() { # <name> <expected: ok|fail> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    failures=$((failures + 1))
  fi
}

DEV=plugins/raftkit-dev
IMPL=$DEV/skills/implement
FIX=$DEV/skills/fix
SG=$DEV/skills/scope-guard
DOCS=$DEV/skills/docs

# DF1 · every dev-flow skill loads the rules itself (cross-group sentence C4)
rules_line='Load `raftkit-core:rules` first unless it is already in this conversation.'
ok=0
for f in "$IMPL/SKILL.md" "$FIX/SKILL.md" "$SG/SKILL.md" "$DOCS/SKILL.md"; do
  grep -qF "$rules_line" "$f" || { echo "  missing the rules line: $f"; ok=1; }
  grep -qF '`raftkit-core:rules` apply' "$f" && { echo "  still says rules apply: $f"; ok=1; }
done
check "DF1 implement, fix, scope-guard and docs load raftkit-core:rules first" ok $ok

echo
echo "dev-flow: $failures failure(s)"
[[ "$failures" -eq 0 ]]
