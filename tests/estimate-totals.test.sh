#!/usr/bin/env bash
# The one arithmetic check in the repo: every ```output block in the estimate
# skill that carries a `Total:` line must add up (lows to lows, highs to highs)
# from the FE/BE/QA feature bullets above it. Drives scripts/check-estimate-totals.mjs.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
export NODE_DISABLE_COLORS=1
node scripts/check-estimate-totals.mjs plugins/raftkit-pm/skills/estimate/SKILL.md plugins/raftkit-pm/skills/estimate/references/sheet.md
code=$?
if [[ $code -eq 0 ]]; then echo "PASS: estimate examples add up"; else echo "FAIL: estimate examples do not add up (exit $code)"; fi
exit $code
