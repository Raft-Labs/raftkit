#!/usr/bin/env bash
# Contract suite for Gate 1's Design Approach + scope-guard's fourth mapping
# surface (raftkit board — S3 of the design-quality-enforcement programme).
# Placement-aware: seams must appear in their owning section, not merely
# somewhere in a file.
#
# Today every quality lens in RaftKit fires AFTER the code exists, and a
# purely structural extraction (no new [AC], no behaviour change) maps to no
# accepted scope-guard surface — it fail-closes into BEYOND, so good design is
# processed through the scope-violation sign-off path. This suite pins a
# Gate-1-approved "Design Approach" artifact that scope-guard treats as a
# fourth, tightly-constrained mapping surface.
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

DA="$DEV/implement/references/design-approach.md"
GATES="$DEV/implement/references/gates.md"
EXEC="$DEV/implement/references/execution.md"
IMPLSKILL="$DEV/implement/SKILL.md"
AM="$DEV/scope-guard/references/audit-method.md"
SGSKILL="$DEV/scope-guard/SKILL.md"

[[ -f "$DA" ]] || { echo "FATAL: $DA not found"; exit 2; }

# --- DA: the artifact itself ---

grep -q '\*\*Decision\*\*' "$DA" && grep -q '\*\*Alternative rejected\*\*' "$DA" \
  && grep -q '\*\*Why\*\*' "$DA" && grep -q '\*\*Phases\*\*' "$DA" \
  && grep -qi 'Deliberately not doing' "$DA"
check "DA1 all five fields specified (Decision, Alternative rejected, Why, Phases, Deliberately not doing)" ok $?

grep -qi '0 to 6\|0–6\|0-6' "$DA" && grep -qi 'more than 6' "$DA"
check "DA2 the 0-6 cap is stated with an explicit overflow rule" ok $?

grep -qi 'No new structure' "$DA" && grep -qi 'legitimate' "$DA" && grep -qi 'cheap' "$DA"
check "DA3 a zero-decision answer is shown and called out as legitimate and cheap" ok $?

grep -qi 'restates an .\[AC\]' "$DA" && grep -qi 'strawman' "$DA" \
  && grep -q 'SOLID' "$DA" && grep -qi 'one caller' "$DA" && grep -qi 'More than 6 rows' "$DA"
check "DA4 rejectable conditions enumerated (AC restated, strawman, principle-name Why, single-caller, cap)" ok $?

grep -qF 'Design Approach amendment — /implement' "$DA"
check "DA5 the mid-build amendment carries its exact fixed header" ok $?

amend=$(sed -n '/^## Mid-build amendment/,$p' "$DA")
grep -qi 'refused' <<<"$amend" && grep -qi '\bPM\b' <<<"$amend"
check "DA6 an amendment adding AC-uncovered work is refused and routed to the PM" ok $?

# --- GATES: Gate 1 wiring ---

g1=$(sec "$GATES" '^## Gate 1' '^## Gate 2')
grep -qi 'Design Approach' <<<"$g1" && grep -q 'design-approach.md' <<<"$g1"
check "GATES1 Gate 1 presents a Design Approach step, referencing design-approach.md" ok $?

! grep -qi 'persist the plan two ways' <<<"$g1"
check "GATES2a old 'two ways' persistence language is gone" ok $?
grep -qi 'persist the plan three ways' <<<"$g1"
check "GATES2b Gate 1 now persists the plan three ways" ok $?

spec_bullet=$(sec "$GATES" 'Write it to the spec file' '^## Gate 2')
grep -qF '## Design Approach' <<<"$spec_bullet" && grep -qi 'section' <<<"$spec_bullet"
check "GATES3 the spec-write step names the '## Design Approach' section explicitly" ok $?

grep -qi 'approvable test' <<<"$g1"
check "GATES4 approval is gated on the Design Approach passing its approvable test" ok $?

# --- EXEC: spec lifecycle ---

nospec=$(sec "$EXEC" '^## No spec, no code' '^## Pre-edit baseline')
grep -q '## Design Approach' <<<"$nospec" && grep -q 'design-approach.md' <<<"$nospec"
check "EXEC1 'No spec, no code' names the spec's Design Approach section" ok $?

# --- IMPLSKILL: Gate 1 summary + reference list ---

grep -qi 'Design Approach' "$IMPLSKILL" && grep -qi '0.{0,3}6\|zero' "$IMPLSKILL"
check "IMPLSKILL1 implement/SKILL.md's Gate 1 summary names the Design Approach" ok $?

grep -q 'references/design-approach.md' "$IMPLSKILL"
check "IMPLSKILL2 implement/SKILL.md's reference list includes design-approach.md" ok $?

# --- AM: scope-guard's fourth mapping surface + reverse MISSING walk ---

map=$(sec "$AM" '^## Mapping each changed item' '^## Documentation edits map like code')
grep -qi 'Gate-1-approved Design Approach decision' <<<"$map"
check "AM1a the mapping walk names the Design Approach decision as a surface" ok $?
grep -qi 'phase' <<<"$map" && grep -qi 'pure relocation or re-pointing' <<<"$map" \
  && grep -qi 'carries that .\?AC' <<<"$map"
check "AM1b admission requires the phase join-key AND a pure relocation carrying an existing AC" ok $?
grep -qi 'never back-dated\|approval must predate the code' <<<"$map"
check "AM2 the surface cannot be back-dated at Gate 2 — approval must predate the code" ok $?
grep -qi 'quoted by its decision number' <<<"$map"
check "AM3 the reverse MISSING walk quotes an unbuilt decision by its decision number" ok $?
grep -qE '^5\. Otherwise' <<<"$map"
check "AM4 the fail-closed default is renumbered (now item 5, after the new surface)" ok $?

# --- SGSKILL: scope-guard's own mirror + the CodeRabbit follow-through ---

grep -qi 'Design Approach decision' "$SGSKILL"
check "SGSKILL1 scope-guard/SKILL.md's frontmatter names the Design Approach surface" ok $?
grep -qi 'quoted by its decision number' "$SGSKILL"
check "SGSKILL2 scope-guard/SKILL.md's MISSING description quotes decision numbers" ok $?
! grep -qi 'coderabbit' "$SGSKILL"
check "SGSKILL3 scope-guard/SKILL.md carries zero CodeRabbit mentions (S2's decision applied here too)" ok $?
grep -q 'references/audit-method.md' "$SGSKILL" && grep -qi 'Design Approach' "$SGSKILL"
check "SGSKILL4 the audit-method.md reference bullet mentions the Design Approach" ok $?

# --- eval bundle ---

n=$(find plugins/raftkit-dev/evals/design-approach -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${n:-0}" -ge 6 ]] \
  && ! find plugins/raftkit-dev/evals/design-approach -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print | grep -q . \
  && ! find plugins/raftkit-dev/evals/design-approach -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print | grep -q .
check "EVAL1 >=6 design-approach eval cases, each with prompt.md + graders" ok $?

! grep -l 'Design Approach amendment — /implement' plugins/raftkit-dev/evals/design-approach/*/prompt.md 2>/dev/null | grep -q .
check "EVAL2 eval prompts do not leak the exact amendment header (no-answer-leak)" ok $?

# --- version bump ---

node -e '
  const v = JSON.parse(require("fs").readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json","utf8")).version.split(".").map(Number);
  const min = [0, 24, 0];
  const cmp = v[0]-min[0] || v[1]-min[1] || v[2]-min[2];
  process.exit(cmp >= 0 ? 0 : 1);
'
check "VER1 raftkit-dev version is at least 0.24.0" ok $?

node -e '
  const fs = require("fs");
  const m = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
  const p = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
  const entry = m.plugins.find(x => x.name === "raftkit-dev");
  process.exit(entry && entry.description === p.description ? 0 : 1);
'
check "VER2 marketplace.json description still matches raftkit-dev plugin.json" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
