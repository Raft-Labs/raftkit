#!/usr/bin/env bash
# Contract suite for CI blocking: every tests/*.test.sh runs on every PR,
# through tests/run-all.sh, in parallel, and one red suite fails the job
# without hiding the others.
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

WF=.github/workflows/validate.yml
RUN=tests/run-all.sh
[[ -f "$WF" ]] || { echo "FATAL: $WF not found"; exit 2; }

# The file has exactly one job; everything after `jobs:` is its steps.
job=$(sed -n '/^jobs:/,$p' "$WF")

# CI-1 · the suites run through the runner, which globs them: a suite added
#        later runs with no workflow edit
grep -qE '^\s*run:\s*bash tests/run-all\.sh\s*$' <<<"$job"
check "CI-1 the workflow runs every suite through tests/run-all.sh" ok $?

# CI-2 · no suite is named in the workflow, so the glob is the only list
named=0
for t in tests/*.test.sh; do grep -qF "$(basename "$t")" <<<"$job" && named=$((named + 1)); done
[[ "$named" -eq 0 ]]
check "CI-2 no suite is named in the workflow" ok $?

# Runner behaviour, against throwaway suites.
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
suite() { mkdir -p "$T/$1"; printf '#!/usr/bin/env bash\n%s\n' "$3" > "$T/$1/$2.test.sh"; }

suite mixed a-pass 'echo fine; exit 0'
suite mixed b-fail 'echo "FAIL: the reason it failed"; exit 1'
suite mixed c-pass 'exit 0'
out="$(bash "$RUN" "$T/mixed" 2>&1)"; code=$?
[[ "$code" -ne 0 ]]
check "CI-3 one failing suite fails the run" ok $?
grep -qE '^PASS +a-pass\.test\.sh' <<<"$out" && grep -qE '^FAIL +b-fail\.test\.sh' <<<"$out" && grep -qE '^PASS +c-pass\.test\.sh' <<<"$out"
check "CI-4 every suite reports PASS or FAIL by name, after a failure too" ok $?
grep -qF 'FAIL: the reason it failed' <<<"$out"
check "CI-5 a failing suite's own output is printed" ok $?

suite green one 'exit 0'
suite green two 'exit 0'
bash "$RUN" "$T/green" >/dev/null 2>&1
check "CI-6 all suites green exits 0" ok $?

# Parallel: the first suite waits for a file the second creates. Run one after
# the other in glob order, the first times out and fails.
suite parallel a-waits "for i in \$(seq 100); do [[ -f '$T/parallel/started' ]] && exit 0; sleep 0.1; done; exit 1"
suite parallel b-starts "touch '$T/parallel/started'"
bash "$RUN" "$T/parallel" >/dev/null 2>&1
check "CI-7 suites run in parallel" ok $?

mkdir -p "$T/empty"
bash "$RUN" "$T/empty" >/dev/null 2>&1
check "CI-8 a directory with no suites is a failure, never a pass" fail $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
