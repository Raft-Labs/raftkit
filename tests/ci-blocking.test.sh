#!/usr/bin/env bash
# Contract suite for CI blocking (raftkit board — "CI: make every contract
# suite blocking", S1 of the design-quality-enforcement programme).
#
# Today only tests/validate.test.sh runs in CI (.github/workflows/validate.yml).
# The other twelve suites are green locally but can silently rot since nothing
# blocks a PR on them. This suite pins that every tests/*.test.sh runs on every
# PR, the opt-in network suite is excluded by name with its reason stated, the
# loop keeps going after a failure (so one red suite doesn't hide the rest),
# and the job fails if any suite failed.
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

[[ -f "$WF" ]] || { echo "FATAL: $WF not found"; exit 2; }

# The file has exactly one job (validate:); everything after the `jobs:` line
# IS that job's steps, so scoping to it is just dropping the header/env preamble.
job=$(sed -n '/^jobs:/,$p' "$WF")

# CI-1 · a step globs every suite — not a fixed list, so a suite added later
# is picked up with no workflow edit.
grep -qF 'tests/*.test.sh' <<<"$job"
check "CI-1 workflow globs tests/*.test.sh (no hardcoded list)" ok $?

# CI-2 · the opt-in network suite is excluded by name, with its reason stated
# alongside it — not silently dropped.
grep -qF 'capability-preflight-network.test.sh' <<<"$job"
check "CI-2 network suite named" ok $?
net=$(sed -n '/capability-preflight-network\.test\.sh/,$p' "$WF")
grep -qiE 'network|opt-in' <<<"$net"
check "CI-2b network exclusion states its reason" ok $?

# CI-3 · no OTHER suite is named literally — proves the glob is real and this
# isn't a re-enumerated allowlist wearing a glob as decoration. Also a
# regression guard: catches a future edit that quietly reverts to a list.
other_named=0
for t in tests/*.test.sh; do
  b="$(basename "$t")"
  [[ "$b" == "capability-preflight-network.test.sh" ]] && continue
  grep -qF "$b" <<<"$job" && other_named=$((other_named + 1))
done
[[ "$other_named" -eq 0 ]]
check "CI-3 no suite other than the excluded one is named literally" ok $?

# CI-4 · the loop survives a failure — a failure counter (or equivalent) means
# the run doesn't abort on the first red suite and hide the rest.
grep -qE 'failures=\$\(\(failures ?\+ ?1\)\)' <<<"$job"
check "CI-4 failures accumulate rather than aborting the loop" ok $?

# CI-5 · the job actually fails when any suite failed.
grep -qE 'failures.{0,15}-gt 0' <<<"$job" && grep -qE '(^|[^_])exit 1([^0-9]|$)' <<<"$job"
check "CI-5 job exits non-zero when any suite failed" ok $?

# CI-6 · the old fixed single-suite step is gone — validate.test.sh now runs
# only via the glob, not as a separate hardcoded invocation.
! grep -qE '^\s*run:\s*bash tests/validate\.test\.sh\s*$' <<<"$job"
check "CI-6 no standalone hardcoded 'bash tests/validate.test.sh' step" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
