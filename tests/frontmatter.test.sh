#!/usr/bin/env bash
# Contract suite for the frontmatter guardrail.
#
# The defect: a plain (unquoted) YAML scalar may not contain ": ". YAML reads
# it as a nested mapping entry and, because the nesting is unindented, the
# whole block fails with "bad indentation of a mapping entry" — so `name`,
# `description` and every other key are lost and the file loads with no
# metadata at all. Six SKILL.md files carried this shape, all on a trailing
# cross-reference (`Fixing: raftkit-dev:fix.`), and nothing in the repo
# caught it: scripts/validate.sh exited 0 with all six present, and
# `claude plugin validate` passed them.
#
# This suite pins: the checker exists and distinguishes its exit codes; each
# negative-control fixture fails exactly the rule it names, with the exact
# exit code and violation text asserted rather than just "nonzero"; each
# positive control passes, so the rule does not over-fire on quoted scalars,
# block scalars, flow collections or URLs; the real repo content is clean;
# and — so a green run here is trustworthy rather than a rubber stamp — the
# defect injected back into a copy of a real skill is still caught.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

failures=0
check() { # <name> <expected: ok|fail> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected $expected, exit was $actual)"
    failures=$((failures + 1))
  fi
}
check_exit() { # <name> <expected exit code> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected exit $expected, got $actual)"
    failures=$((failures + 1))
  fi
}
check_contains() { # <name> <haystack> <needle>
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected output to contain: $needle)"
    failures=$((failures + 1))
  fi
}
check_lacks() { # <name> <haystack> <needle>
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected output NOT to contain: $needle)"
    failures=$((failures + 1))
  fi
}

CHECKER=scripts/check-frontmatter.mjs
FIX=tests/fixtures/frontmatter

# --- CHECKER: exists, is valid JS, and its usage errors are distinguishable
# from "clean" and from "violations found" ---

[[ -f "$CHECKER" ]]
check "FM1a checker script exists" ok $?

node --check "$CHECKER" >/dev/null 2>&1
check "FM1b checker script is syntactically valid" ok $?

node "$CHECKER" >/dev/null 2>&1
check_exit "FM1c no target given exits 2 (a usage error, never 'clean')" 2 $?

out="$(node "$CHECKER" "$FIX/does-not-exist.md" 2>&1)"; code=$?
check_exit "FM1d a nonexistent target exits 2 (never mistaken for 'violations found')" 2 "$code"
check_contains "FM1d reports which target it couldn't read" "$out" "cannot read target"

# The checker must not depend on node_modules: CI installs the pinned Claude
# CLI and never runs `npm install`, so a YAML library would not be there.
! grep -qE "require\(|from \"(js-yaml|yaml)\"|from 'js-yaml'" "$CHECKER"
check "FM1e checker uses no YAML library (node_modules is absent in CI)" ok $?

# --- NEGATIVE CONTROLS: prove the checker catches each fault, and that the
# two faults are not reported as if they had the same consequence ---

out="$(node "$CHECKER" "$FIX/bad-colon-space.md" 2>&1)"; code=$?
check_exit "FM2a rejects a colon-space in an unquoted key value (exit 1)" 1 "$code"
check_contains "FM2a names the key" "$out" 'unquoted value of `description`'
check_contains "FM2a states the real consequence" "$out" "loads with no metadata"

out="$(node "$CHECKER" "$FIX/bad-trailing-colon.md" 2>&1)"; code=$?
check_exit "FM2b rejects an unquoted value ending in a bare colon (exit 1)" 1 "$code"
check_contains "FM2b names the fault" "$out" "ends in a bare"

# A sequence item with a colon-space is legal YAML — it silently becomes a
# mapping rather than breaking the block. Verified against a strict parser.
# The message must not claim the block is rejected.
out="$(node "$CHECKER" "$FIX/bad-list-item.md" 2>&1)"; code=$?
check_exit "FM2c rejects a colon-space in an unquoted sequence item (exit 1)" 1 "$code"
check_contains "FM2c names it as a sequence item" "$out" "unquoted sequence item"
check_lacks "FM2c does not claim a sequence item breaks the whole block" "$out" "loads with no metadata"

out="$(node "$CHECKER" "$FIX/bad-unterminated.md" 2>&1)"; code=$?
check_exit "FM2d rejects an unterminated frontmatter block (exit 1)" 1 "$code"
check_contains "FM2d names it as unterminated" "$out" "unterminated frontmatter block"
check_contains "FM2d an unterminated block's content is still checked, not dropped" "$out" "loads with no metadata"

# --- POSITIVE CONTROLS: the rule must not over-fire ---

node "$CHECKER" "$FIX/good.md" >/dev/null 2>&1
check_exit "FM3a accepts an em-dash cross-reference (exit 0)" 0 $?

node "$CHECKER" "$FIX/good-quoted-colon.md" >/dev/null 2>&1
check_exit "FM3b accepts a colon inside a double- or single-quoted scalar (exit 0)" 0 $?

node "$CHECKER" "$FIX/good-block-scalar.md" >/dev/null 2>&1
check_exit "FM3c accepts a colon inside a block scalar and a flow collection (exit 0)" 0 $?

node "$CHECKER" "$FIX/good-url.md" >/dev/null 2>&1
check_exit "FM3d accepts a URL value, which carries a colon but no colon-space (exit 0)" 0 $?

out="$(node "$CHECKER" "$FIX/no-frontmatter.md" 2>&1)"; code=$?
check_exit "FM3e accepts a file with no frontmatter at all (exit 0)" 0 "$code"
check_contains "FM3e counts no block for a file that has none" "$out" "checked 0 frontmatter block(s)"

# --- REAL CONTENT: every shipped frontmatter block parses ---

real_out="$(node "$CHECKER" plugins 2>&1)"
real_exit=$?
[[ "$real_exit" -eq 0 ]]
check "FM4a every frontmatter block in plugins/ is strict-parseable" ok $?
[[ "$real_exit" -ne 0 ]] && echo "$real_out"

grep -qE '^checked [0-9]+ frontmatter block' <<<"$real_out"
check "FM4b the checker actually scanned blocks, not a silent zero-match pass" ok $?

scanned="$(sed -nE 's/^checked ([0-9]+) frontmatter block.*/\1/p' <<<"$real_out")"
[[ -n "$scanned" && "$scanned" -ge 150 ]]
check "FM4c scanned the whole tree, not a subset ($scanned blocks, floor 150)" ok $?

# --- REGRESSION PIN: the six files that carried the defect ---
#
# Pinned by path so the fix cannot be silently reverted. The rule is applied
# by the checker above; this asserts the specific files a strict parser used
# to reject are the ones being covered.

six=(
  plugins/raftkit-core/skills/working-agreement/SKILL.md
  plugins/raftkit-pm/skills/meeting/SKILL.md
  plugins/raftkit-pm/skills/estimate/SKILL.md
  plugins/raftkit-qa/skills/run-sheet/SKILL.md
  plugins/raftkit-qa/skills/bug/SKILL.md
  plugins/raftkit-docs/skills/docs-product/SKILL.md
)
missing=""
for f in "${six[@]}"; do [[ -f "$f" ]] || missing="$missing $f"; done
[[ -z "$missing" ]]
check "FM5a all six formerly-broken skills still exist" ok $?
[[ -n "$missing" ]] && echo "  missing:$missing"

node "$CHECKER" "${six[@]}" >/dev/null 2>&1
check_exit "FM5b all six formerly-broken skills now parse (exit 0)" 0 $?

# --- MUTATION: the checker is not vacuous against real content ---
#
# Inject the exact defect back into a copy of a real shipped skill and
# require the checker to catch it. A suite that only ever sees hand-made
# fixtures can pass while missing the shape that actually occurs.

mut="$(mktemp -d)"
trap 'rm -rf "$mut"' EXIT
mkdir -p "$mut/skills/bug"
sed 's/^description: \(.*\)$/description: \1 Fixing: raftkit-dev:fix./' \
  plugins/raftkit-qa/skills/bug/SKILL.md > "$mut/skills/bug/SKILL.md"

grep -q 'Fixing: raftkit-dev:fix\.' "$mut/skills/bug/SKILL.md"
check "FM6a the mutation actually landed in the copy" ok $?

node "$CHECKER" "$mut" >/dev/null 2>&1
check_exit "FM6b the injected defect is caught in a real skill (exit 1)" 1 $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
