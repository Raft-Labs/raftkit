#!/usr/bin/env bash
# Deterministic (offline) suite for the capability-preflight skill.
# Story: M3 · capability-preflight (Asana 1216750414254722).
#
# AC → evidence matrix (deterministic tests here; behavioral evals in
# plugins/raftkit-dev/evals/capability-preflight/; network proof in
# tests/capability-preflight-network.test.sh):
#   AC-1  happy path all-ready line ......... T3            + eval routing-all-ready
#   AC-2  five readiness states ............. T3,T4,T5,T10  + eval routing-installed-but-disabled
#   AC-3  verified-dependency gate .......... network suite (per-candidate proof) + T7 (declared set)
#   AC-4  component semantics exact ......... T2 incl. T2f scoped dispatch (independent oracle)
#   AC-5  Asana core-owned .................. T2,T7
#   AC-6  permission boundary ............... T6,T12        + evals routing-missing-proposal, optional-never-dep
#   AC-7  post-approval verification ........ T5 (mismatch detection; T5c per-plugin isolation) + network suite
#   AC-8  skill discovery ................... T12           + eval skill-discovery-suggest-only
#   AC-9  error copy / declared-unresolved .. T4,T12        + evals refusal-after-no, declared-unresolved
#   AC-10 setup-project integration ......... T13
#   AC-11 isolated-config tests ............. network suite (temp CLAUDE_CONFIG_DIR); this suite is offline
#   AC-12 manifests green + lockstep ........ T7,T8 (+ scripts/validate.sh in CI)
#   AC-13 plugin evals ...................... T11 (suite present) — EXECUTION PENDING: the
#         plugin/no-plugin arms have not run (runner is early-access gated, exit 1,
#         recorded in isolated config); AC-13 is authored + structurally verified only
set -uo pipefail
cd "$(dirname "$0")/.."

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

SKILL=plugins/raftkit-dev/skills/capability-preflight
CLASSIFY=$SKILL/scripts/classify.mjs
REGISTRY=$SKILL/references/providers.md
FIX=tests/fixtures/capability

run_classify() { # <plugins fixture> [extra args...] -> stdout in $OUT, exit in $?
  local plugins="$1"; shift
  OUT=$(node "$CLASSIFY" --registry "$REGISTRY" --plugins "$FIX/$plugins" --skills-global "$FIX/skills-global.json" "$@" 2>&1)
}

# T1 · registry + classifier exist and parse
[[ -f "$REGISTRY" ]]; check "T1a registry exists" ok $?
run_classify plugins-all-ready.json --json >/dev/null
check "T1b classifier parses registry + fixtures" ok $?

# T2 · story-approved component semantics — independent oracle (amendment 3):
#      these expectations are fixed HERE, so the test fails if providers.md
#      drifts from the approved story facts, instead of echoing whatever it says.
grep -Eq 'security-guidance.*hooks: SessionStart, UserPromptSubmit, PostToolUse, Stop' "$REGISTRY" 2>/dev/null \
  && grep -q 'hook-only' "$REGISTRY"
check "T2a security-guidance is hook-only with the four hooks" ok $?
grep -Eq 'code-simplifier.*agent: code-simplifier' "$REGISTRY" 2>/dev/null
check "T2b code-simplifier is an agent dispatch" ok $?
grep -Eq 'superpowers.*skills: brainstorming, writing-plans, test-driven-development, systematic-debugging, verification-before-completion' "$REGISTRY" 2>/dev/null
check "T2c superpowers exposes the five verified named skills" ok $?
grep -Eq 'pr-review-toolkit.*inventory-at-verification' "$REGISTRY" 2>/dev/null
check "T2d pr-review-toolkit inventory is discovered at verification" ok $?
grep -Eq '[Aa]sana.*raftkit-core \(inherited\)' "$REGISTRY" 2>/dev/null
check "T2e Asana ownership stays raftkit-core (inherited)" ok $?
grep -qF 'code-simplifier:code-simplifier' "$REGISTRY" 2>/dev/null
check "T2f registry records the scoped agent dispatch type (bare name collides with pr-review-toolkit)" ok $?

# T3 · happy path: every required capability ready -> exact all-ready line, no plan
run_classify plugins-all-ready.json --details "$FIX/details-ok"
check "T3a all-ready run exits 0" ok $?
grep -qF 'Capability preflight: all required capabilities ready.' <<<"$OUT"
check "T3b exact all-ready line" ok $?
grep -qF 'Proposed install command' <<<"$OUT"
check "T3c no install plan drafted when all ready" fail $?

# T4 · mixed inventory: declared-unresolved + installed-but-disabled + summary line
run_classify plugins-mixed.json --need expo
check "T4a mixed run exits nonzero (action required)" fail $?
grep -qF 'unresolved declared dependency: pr-review-toolkit' <<<"$OUT"
check "T4b declared dep missing reported as unresolved, not proposed" ok $?
grep -q 'human-approved RaftKit install/update' <<<"$OUT"
check "T4c declared-unresolved guidance points to RaftKit install/update" ok $?
grep -qF 'installed-but-disabled' <<<"$OUT" && grep -qF 'claude plugin enable expo' <<<"$OUT"
check "T4d installed-but-disabled names the exact enable command" ok $?
grep -qE 'Capability preflight: [0-9]+ ready, [0-9]+ missing, [0-9]+ installed-but-disabled — install plan awaiting approval\.' <<<"$OUT"
check "T4e exact summary-with-plan line" ok $?
grep -qF 'claude plugin install pr-review-toolkit' <<<"$OUT"
check "T4f no runtime install command for a declared dependency" fail $?

# T5 · component mismatch: details show the agent is gone -> incompatible, named
run_classify plugins-all-ready.json --details "$FIX/details-mismatch"
check "T5a mismatch run exits nonzero" fail $?
grep -qF 'incompatible' <<<"$OUT" && grep -qE 'code-simplifier.*missing component.*agent: code-simplifier' <<<"$OUT"
check "T5b incompatible names the absent component" ok $?
# Regression: pr-review-toolkit's SAME-NAMED code-simplifier agent is present in
# this details dir; it must never satisfy the code-simplifier plugin's component
# check — inventories are strictly per-plugin (scoped dispatch, no cross-bleed).
grep -q 'code-simplifier' "$FIX/details-mismatch/pr-review-toolkit.txt" \
  && grep -qF 'incompatible' <<<"$OUT"
check "T5c another plugin's same-named agent cannot satisfy the component check" ok $?

# T6 · the classifier is a pure reader: it never executes anything
grep -qE 'exec|spawn|execSync|child_process' "$CLASSIFY" 2>/dev/null
check "T6 classifier contains no process execution" fail $?

# T7 · manifests: verified declared deps, allowlist, no asana dep
node -e '
  const fs = require("fs");
  const p = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
  const deps = (p.dependencies || []).map(d => typeof d === "string" ? d : d.name);
  const want = ["raftkit-core","superpowers","claude-md-management","code-simplifier","security-guidance","pr-review-toolkit"];
  const officials = (p.dependencies || []).filter(d => typeof d === "object");
  if (!want.every(w => deps.includes(w))) process.exit(1);
  if (deps.some(d => /asana/i.test(d))) process.exit(2);
  if (!officials.every(d => d.marketplace === "claude-plugins-official")) process.exit(3);
'
check "T7a plugin.json declares the verified deps, none for asana" ok $?
node -e '
  const m = JSON.parse(require("fs").readFileSync(".claude-plugin/marketplace.json", "utf8"));
  const allow = m.allowCrossMarketplaceDependenciesOn;
  process.exit(Array.isArray(allow) && allow.length === 1 && allow[0] === "claude-plugins-official" ? 0 : 1);
'
check "T7b allowlist is exactly [claude-plugins-official]" ok $?
node -e '
  const fs = require("fs");
  const m = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
  const p = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
  const entry = m.plugins.find(x => x.name === "raftkit-dev");
  process.exit(entry.description === p.description && /capability preflight/i.test(p.description) ? 0 : 1);
'
check "T7c description lockstep includes capability preflight" ok $?

# T8 · version bumped for this story
node -e 'process.exit(JSON.parse(require("fs").readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json","utf8")).version === "0.12.0" ? 0 : 1)'
check "T8 raftkit-dev version is 0.12.0" ok $?

# T9 · scope uncertainty: no parent plugin entry -> ask, never assume
run_classify plugins-no-parent.json
grep -q 'Scope: ask the developer' <<<"$OUT"
check "T9 unknown install scope asks instead of assuming" ok $?

# T10 · optional/conditional absent without --need -> optional-not-selected, no proposal
run_classify plugins-mixed.json
grep -qE 'neon.*optional-not-selected' <<<"$OUT"
check "T10a absent conditional provider is optional-not-selected" ok $?
grep -qF 'claude plugin install neon' <<<"$OUT"
check "T10b no proposal for an unselected optional provider" fail $?

# T11 · behavioral eval suite exists in the official layout (prompt.md + graders/*.md)
n=$(find plugins/raftkit-dev/evals/capability-preflight -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${n:-0}" -ge 7 ]] && ! find plugins/raftkit-dev/evals/capability-preflight -mindepth 1 -maxdepth 1 -type d \
  '!' -exec test -f '{}/prompt.md' ';' -print | grep -q . \
  && ! find plugins/raftkit-dev/evals/capability-preflight -mindepth 1 -maxdepth 1 -type d \
  '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print | grep -q .
check "T11 >=7 eval cases each with prompt.md + graders" ok $?

# T12 · SKILL.md carries the approved contract strings verbatim
S=$SKILL/SKILL.md
grep -qF 'user-invocable: false' "$S" 2>/dev/null;                                   check "T12a skill is not user-invocable" ok $?
grep -qF 'Capability preflight: all required capabilities ready.' "$S" 2>/dev/null;  check "T12b all-ready line in contract" ok $?
grep -qF 'install plan awaiting approval.' "$S" 2>/dev/null;                          check "T12c plan-summary line in contract" ok $?
grep -qF 'Required capability unavailable: <capability>. Proposed install command (human approval required): <exact command>. Stopping — no fallback.' "$S" 2>/dev/null
check "T12d exact refusal error copy" ok $?
grep -qF 'installed-but-disabled' "$S" 2>/dev/null;                                   check "T12e canonical installed-but-disabled naming" ok $?
grep -q 'never adds or installs them at runtime' "$S" 2>/dev/null;                    check "T12f declared-vs-runtime separation stated" ok $?
grep -q 'npx skills find' "$S" 2>/dev/null && grep -q 'never install' "$S" 2>/dev/null
check "T12g skills-find is suggest-only" ok $?

# T13 · setup-project integration: preflight named in Phase 1, declared deps stop-not-install
grep -q 'capability-preflight' plugins/raftkit-dev/skills/setup-project/references/install-flow.md 2>/dev/null
check "T13a install-flow runs the capability preflight" ok $?
grep -q 'human-approved RaftKit install/update' plugins/raftkit-dev/skills/setup-project/references/install-flow.md 2>/dev/null
check "T13b unresolved declared deps stop with repair guidance" ok $?

# Optional: attempt the official eval runner in an ISOLATED config (never the live one).
# Currently records the early-access gate; becomes the green rerun when ungated.
if [[ "${RUN_EVALS:-0}" == "1" ]]; then
  evtmp="$(mktemp -d)"
  CLAUDE_CONFIG_DIR="$evtmp" claude plugin eval plugins/raftkit-dev --case 'capability*' --runs 1 2>&1 | tail -5
  echo "note: plugin eval exit=$? (early-access gate expected until enabled)"
  rm -rf "$evtmp"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
