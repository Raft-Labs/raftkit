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

# DF2 · the squash target is settled in turn 1: its stop sits in intake, before
#       readiness, and nothing points at a release-train doc no repo carries
stop_line="$(grep -n '^no documented squash target — ' "$IMPL/SKILL.md" | head -1 | cut -d: -f1)"
ready_line="$(grep -n '^2\. \*\*Check readiness' "$IMPL/SKILL.md" | head -1 | cut -d: -f1)"
[[ -n "$stop_line" && -n "$ready_line" && "$stop_line" -lt "$ready_line" ]] \
  && ! grep -rqi 'release-train doc\|release-train convention' "$IMPL" \
  && ! grep -qF 'no documented squash target' "$IMPL/references/pr.md"
check "DF2 implement stops on an undocumented squash target at intake, not at the raise" ok $?

# DF3 · the plan record implement writes is exempt in scope-guard (same path)
plan_path="$(grep -o 'Write the plan to `[^`]*`' "$IMPL/SKILL.md" | head -1 | sed 's/.*`\(.*\)`/\1/')"
[[ -n "$plan_path" ]] && grep -F "\`$plan_path\`" "$SG/SKILL.md" | grep -qF 'always in scope'
check "DF3 scope-guard never flags implement's plan record (${plan_path:-no path found})" ok $?

# DF4 · scope-guard reads out-of-scope where the live Feature Template puts it
grep -qF '`Do NOT build`' "$SG/SKILL.md"
check "DF4 scope-guard reads the out-of-scope list from the Do NOT build line" ok $?

echo
echo "dev-flow: $failures failure(s)"
[[ "$failures" -eq 0 ]]
