#!/usr/bin/env bash
# Network integration suite for the capability-preflight story (AC-3, AC-7, AC-11).
# Proves, per candidate hard dependency, in an ISOLATED temporary CLAUDE_CONFIG_DIR
# (never the live config): marketplace resolution -> install -> enablement ->
# component inventory -> tag/version behavior.
#
# Opt-in: RUN_NETWORK_TESTS=1 bash tests/capability-preflight-network.test.sh
# Exit codes: 0 all candidates verified · 1 genuine verification failure (evidence
# printed; candidate must stay undeclared) · 3 transient environment failure
# (network/auth/CLI) — NEVER to be recorded as a registry fact (story amendment:
# a transient experiment failure is not evidence a provider is unsupported).
set -uo pipefail
cd "$(dirname "$0")/.."

if [[ "${RUN_NETWORK_TESTS:-0}" != "1" ]]; then
  echo "skipped: set RUN_NETWORK_TESTS=1 to run (needs network + claude CLI)"
  exit 0
fi
command -v claude >/dev/null 2>&1 || { echo "SKIP (transient): claude CLI not on PATH"; exit 3; }

failures=0
CFG="$(mktemp -d)"
trap 'rm -rf "$CFG"' EXIT
export CLAUDE_CONFIG_DIR="$CFG"
echo "isolated CLAUDE_CONFIG_DIR=$CFG (live config untouched)"

# Marketplace resolution — failure here is transient/environmental, not provider evidence.
if ! claude plugin marketplace add anthropics/claude-plugins-official >/dev/null 2>&1; then
  echo "SKIP (transient): could not add claude-plugins-official marketplace (network/auth?)"
  exit 3
fi

# Independent expected-component oracle (story-approved semantics — keep in sync
# with T2 of tests/capability-preflight.test.sh, NOT with providers.md).
verify() { # <plugin> <grep-pattern for details output> <label>
  local plugin="$1" pattern="$2" label="$3" out
  if ! claude plugin install "$plugin@claude-plugins-official" -s user >/dev/null 2>&1; then
    echo "SKIP (transient): install of $plugin failed (network/auth?) — not provider evidence"
    exit 3
  fi
  claude plugin enable "$plugin" >/dev/null 2>&1 # enabled-by-default is fine; enable must not error fatally
  out="$(claude plugin details "$plugin" 2>&1)"
  if grep -Eq "$pattern" <<<"$out"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — inventory did not match; evidence follows"
    echo "$out" | head -15
    failures=$((failures + 1))
  fi
}

verify superpowers 'Skills \([0-9]+\).*brainstorming.*systematic-debugging.*test-driven-development' \
  "superpowers installs and exposes the named skills"
verify claude-md-management 'Skills \([0-9]+\)' \
  "claude-md-management installs with its skills"
verify code-simplifier 'Agents \(1\)[[:space:]]+code-simplifier' \
  "code-simplifier installs and exposes the code-simplifier agent"
verify security-guidance 'Hooks \(4\).*SessionStart' \
  "security-guidance installs hook-only (4 hooks)"
verify pr-review-toolkit 'Component inventory' \
  "pr-review-toolkit installs; inventory discovered and printed"
claude plugin details pr-review-toolkit 2>&1 | sed -n '/Component inventory/,/Projected/p'

# Tag/version behavior: dependencies stay unversioned unless {name}--v{version} tags exist.
tags="$(git ls-remote --tags https://github.com/anthropics/claude-plugins-official 2>/dev/null | grep -c -- '--v' || true)"
if [[ -z "$tags" ]]; then
  echo "SKIP (transient): could not list upstream tags"
else
  echo "upstream {name}--v{version} tag count: $tags (0 => declare dependencies unversioned)"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "$failures candidate(s) failed verification — they must stay undeclared (see story AC-3)"
  exit 1
fi
echo "all candidates verified in isolated config"
