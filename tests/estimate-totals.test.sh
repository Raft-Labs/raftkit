#!/usr/bin/env bash
# The one arithmetic check in the repo: every ```output block in the estimate
# skill that carries a `Total:` line must add up (lows to lows, highs to highs)
# from the FE/BE/QA feature bullets above it, and every feature bullet must
# state its own `total a–b h`, equal to the sum of its three ranges — the stop
# shows every total the Sheet will hold. Drives scripts/check-estimate-totals.mjs.
#
# The fixtures prove the checker catches each fault it claims to, with the
# exact exit code and message asserted, so a green run is not a rubber stamp.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
export NODE_DISABLE_COLORS=1

failures=0
check() { # <name> <expected exit> <actual exit> [haystack needle]
  local name="$1" expected="$2" actual="$3" haystack="${4:-}" needle="${5:-}"
  if [[ "$actual" -eq "$expected" && ( -z "$needle" || "$haystack" == *"$needle"* ) ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected exit $expected${needle:+ and \"$needle\"}, got exit $actual)"
    [[ -n "$haystack" ]] && echo "  output: $haystack"
    failures=$((failures + 1))
  fi
}

CHECKER=scripts/check-estimate-totals.mjs
FIX=tests/fixtures/estimate-totals

out="$(node "$CHECKER" plugins/raftkit-pm/skills/estimate/SKILL.md plugins/raftkit-pm/skills/estimate/references/sheet.md 2>&1)"
check "ET1 the shipped estimate examples add up, per feature and in total" 0 $? "$out" "all add up"

out="$(node "$CHECKER" "$FIX/good.md" 2>&1)"
check "ET2 a compliant example passes, no over-firing" 0 $? "$out" "all add up"

out="$(node "$CHECKER" "$FIX/bad-feature-total.md" 2>&1)"
check "ET3 a feature total that does not match its ranges fails" 1 $? "$out" "Export totals 3–6 h, but its FE, BE and QA ranges sum to 3–5 h"

out="$(node "$CHECKER" "$FIX/bad-missing-feature-total.md" 2>&1)"
check "ET4 a feature bullet with no total of its own fails" 1 $? "$out" "feature bullet states no total"

out="$(node "$CHECKER" "$FIX/bad-list-total.md" 2>&1)"
check "ET5 a list total that does not match the features fails" 1 $? "$out" "Total totals 12–20 h, but the feature bullets sum to 12–19 h"

node "$CHECKER" >/dev/null 2>&1
check "ET6 no target is a usage error (exit 2), never clean" 2 $?

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
