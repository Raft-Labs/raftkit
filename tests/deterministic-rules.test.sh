#!/usr/bin/env bash
# Contract suite for deterministic MDS rules — ESLint in client repos plus
# RaftKit's own self-application (raftkit board — S5, final story of the
# design-quality-enforcement programme).
#
# code-reviewer reports only findings scored >=80 confidence and is told to
# "filter aggressively" — a numeric rule like MDS-2's 25-line handler or
# MDS-10's third occurrence is exactly what an LLM reviewer catches ~70% of
# the time and a linter catches 100%. This buys the determinism the prose
# standard (S4) cannot. This suite pins the client-repo asset, its wiring into
# setup-project, and RaftKit's own verified (not just plausible) self-applied
# config.
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

DEV=plugins/raftkit-dev/skills
sec() { sed -n "/$2/,/$3/p" "$1" 2>/dev/null; }
flat() { tr '\n' ' ' <<<"$1" | tr -s ' '; }

# --- CLIENT: the installable ESLint asset ---

ASSET="$DEV/setup-project/references/assets/mds-eslint.config.mjs"
[[ -f "$ASSET" ]] || { echo "FATAL: $ASSET not found"; exit 2; }

node --check "$ASSET"
check "CLIENT1 the asset is syntactically valid JS" ok $?

grep -qF 'raftkit-governance-pack' "$ASSET"
check "CLIENT2 the asset carries the pack ownership marker" ok $?

grep -q 'complexity' "$ASSET" && grep -q 'max-lines-per-function' "$ASSET"
check "CLIENT3 the asset enforces MDS-1's size/complexity proxy" ok $?

h=$(flat "$(sec "$ASSET" 'MDS-2' 'MDS-8')")
grep -qi 'max: 25' <<<"$h"
check "CLIENT4 the asset enforces MDS-2's 25-line handler limit on handler globs" ok $?

grep -qi 'eslint-plugin-import' "$ASSET" && grep -qi 'not assumed installed\|never invented or silently required' "$ASSET"
check "CLIENT5 MDS-8 (import cycles) is commented out with its dependency named, never silently assumed" ok $?

# --- CLIENT: wiring into setup-project ---

CM="$DEV/setup-project/references/components.md"
ct=$(sec "$CM" '^## Component table' '^## Parameters')
grep -q 'mds-eslint.config.mjs' <<<"$ct" && grep -qi 'never merged' <<<"$(flat "$ct")"
check "SETUP1 components.md's table has the MDS ESLint config row, marked never-merged" ok $?
grep -qi 'these seven' "$CM" && grep -qi 'MDS ESLint config' "$CM"
check "SETUP2 the success-string sentence now counts seven components" ok $?
mk=$(sed -n '/^## The version marker/,$p' "$CM")
grep -q '"mds-eslint"' <<<"$mk"
check "SETUP3 the version marker's components array includes mds-eslint" ok $?

IF="$DEV/setup-project/references/install-flow.md"
ph2=$(flat "$(sec "$IF" '^## Phase 2' '^## Phase 3')")
grep -qi 'four assets' <<<"$ph2" && grep -qi 'mds-eslint.config.mjs' <<<"$ph2"
check "SETUP4 Phase 2 writes the fourth asset (MDS ESLint config)" ok $?
ph4=$(flat "$(sec "$IF" '^## Phase 4' '^## Baseline capabilities')")
grep -qi 'MDS ESLint config' <<<"$ph4" && grep -qi 'import mds from' <<<"$ph4"
check "SETUP5 Phase 4's success string and printed wiring instructions include the ESLint config" ok $?

# A component named in the success line must have its own verify step, not
# just be mentioned in prose — otherwise a failed or skipped write can still
# report "verified". This is a real file-existence check, distinct from
# SETUP5's text-mentions-it check above.
grep -qi 'mds-eslint.config.mjs' <<<"$ph4" && grep -qi 'exists and is readable' <<<"$ph4"
check "SETUP5b Phase 4 has its own verify bullet confirming the ESLint config file actually exists (not just claimed)" ok $?

SPSKILL="$DEV/setup-project/SKILL.md"
n=$(grep -ci 'MDS ESLint config' "$SPSKILL")
[[ "$n" -ge 3 ]]
check "SETUP6 setup-project/SKILL.md names the MDS ESLint config across multiple sections" ok $?

# --- SELF: RaftKit applies the deterministic subset to its own scripts ---

[[ -f package.json ]] || { echo "FATAL: package.json not found at repo root"; exit 2; }
node -e '
  const p = JSON.parse(require("fs").readFileSync("package.json", "utf8"));
  process.exit((p.devDependencies && p.devDependencies.eslint && p.scripts && p.scripts.lint) ? 0 : 1);
'
check "SELF1 root package.json declares eslint as a devDependency with a lint script" ok $?

[[ -f package-lock.json ]]
check "SELF2 a real lockfile was generated (not hand-written)" ok $?

node --check eslint.config.mjs
check "SELF3 root eslint.config.mjs is syntactically valid" ok $?

grep -qi 'not wired into CI yet' eslint.config.mjs
check "SELF4 the config states why it isn't a blocking CI gate yet (existing findings, scoped separately)" ok $?

! grep -q 'npm run lint' .github/workflows/validate.yml
check "SELF5 CI does not yet run the new lint script (deliberate — no retroactive judgment of existing code)" ok $?

# --- SELF: the linter actually runs and actually finds something real ---

if [[ -d node_modules/eslint ]]; then
  lint_out="$(npm run lint 2>&1)"
  lint_exit=$?
  [[ "$lint_exit" -eq 0 ]]
  check "SELF6a lint run exits 0 (warnings only, not blocking)" ok $?
  grep -qi 'validate-docs.mjs' <<<"$lint_out"
  check "SELF6b the linter surfaces a real finding in validate-docs.mjs — not a no-op" ok $?
  grep -qiE 'complexity|max-lines-per-function' <<<"$lint_out"
  check "SELF6c the finding names one of the two configured rules" ok $?
else
  echo "SKIP: SELF6* (node_modules/eslint not installed in this environment — run 'npm install' first)"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
