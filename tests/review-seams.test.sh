#!/usr/bin/env bash
# Contract suite for "Repair the review seams" (raftkit board — S2 of the
# design-quality-enforcement programme). Placement-aware: seams must appear
# in their owning section, not merely somewhere in a file.
#
# Three things were false before this story:
#   1. pr-review-toolkit:review-pr was invoked post-push on a clean tree,
#      where the tool's own default (unstaged git diff) is empty.
#   2. simplify's SKILL.md invoked ponytail:ponytail-review — a plugin that
#      is not installed and is in no registered marketplace.
#   3. Gate 2 still mandated a CodeRabbit local pass three weeks after
#      RaftLabs decided against it (Asana 1216551482947559, closed 2026-07-14).
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

AR="$DEV/pr/references/automated-review.md"
PRSKILL="$DEV/pr/SKILL.md"
IMPLSKILL="$DEV/implement/SKILL.md"
GATES="$DEV/implement/references/gates.md"
CLOSEOUT="$DEV/implement/references/close-out.md"
PROVIDERS="$DEV/capability-preflight/references/providers.md"
SIMPLIFY="$DEV/simplify/SKILL.md"
CATALOG="$DEV/simplify/references/candidate-catalog.md"

# --- R1-R4: automated-review.md — the empty-diff fix, aspects, CodeRabbit ---

scope=$(sec "$AR" '^## Scope' '^## The layers')
grep -qi 'merge-base' <<<"$scope" && grep -qi 'unstaged\|empty' <<<"$scope"
check "R1 automated-review states the merge-base range and names the empty-diff hazard" ok $?

layers=$(sec "$AR" '^## The layers' '^## The gate')
grep -q 'type-design-analyzer' <<<"$layers" && grep -qi 'unconditional\|always' <<<"$layers"
check "R2 types aspect is unconditional, type-design-analyzer named as reason" ok $?

grep -qi 'revert-safety.md' <<<"$layers" && grep -qi 'simplify.*exclud\|exclud.*simplify' <<<"$layers"
check "R3 simplify aspect excluded from review-pr, cites revert-safety.md" ok $?

grep -q '1216551482947559' <<<"$layers" && grep -qi 'closed 2026-07-14' <<<"$layers"
check "R4 CodeRabbit-not-in-use cites the closed decision with its date" ok $?

! grep -qi 'when present' <<<"$layers"
check "R4b old conditional CodeRabbit phrasing is gone" ok $?

# --- R5-R7: no stray CodeRabbit mentions in the skills that delegate the detail ---

! grep -qi 'coderabbit' "$PRSKILL"
check "R5 pr/SKILL.md carries zero CodeRabbit mentions (detail lives in automated-review.md)" ok $?

! grep -qi 'coderabbit' "$IMPLSKILL"
check "R6 implement/SKILL.md carries zero CodeRabbit mentions" ok $?

! grep -qi 'coderabbit' "$CLOSEOUT"
check "R7 close-out.md carries zero CodeRabbit mentions" ok $?

# --- R8: Gate 2 no longer mandates a CodeRabbit local pass ---

g2=$(sec "$GATES" '^## Gate 2' '^## Gate evidence')
! grep -qi 'CodeRabbit local pass' <<<"$g2"
check "R8a Gate 2 no longer mandates a CodeRabbit local pass" ok $?
grep -q '1216551482947559' <<<"$g2"
check "R8b Gate 2 cites the closed decision" ok $?
! grep -qi 'only when both are satisfied' <<<"$g2"
check "R8c 'both' language dropped (only one blocking Gate 2 item remains)" ok $?

# --- R9: providers.md — ponytail row gone, coderabbit row reflects closure ---

! grep -qi 'ponytail' "$PROVIDERS"
check "R9a providers.md has no ponytail row" ok $?
cr_row=$(grep -i 'pr-annotations' "$PROVIDERS")
grep -q '1216551482947559' <<<"$cr_row" && grep -qi 'not in use\|closed' <<<"$cr_row"
check "R9b providers.md coderabbit row states it is not in use, citing the decision" ok $?

# --- R10-R11: simplify no longer depends on ponytail ---

! grep -qi 'ponytail' "$SIMPLIFY"
check "R10a simplify/SKILL.md has no ponytail mention" ok $?
grep -qi 'candidate-catalog' "$SIMPLIFY" && grep -qiE "RaftKit.{0,20}minimalism|minimalism.{0,20}RaftKit" "$SIMPLIFY"
check "R10b simplify/SKILL.md names candidate-catalog as RaftKit's own minimalism lens" ok $?

! grep -qi 'ponytail' "$CATALOG"
check "R11a candidate-catalog.md has no ponytail mention" ok $?
grep -qiE "RaftKit.{0,20}minimalism|minimalism.{0,20}RaftKit|own minimalism lens" "$CATALOG"
check "R11b candidate-catalog.md states it IS RaftKit's own minimalism lens" ok $?

# --- R12: CLAUDE.md — no ponytail, no CodeRabbit, decision row dropped ---

! grep -qi 'ponytail' CLAUDE.md
check "R12a CLAUDE.md has no ponytail mention" ok $?
! grep -qi 'coderabbit' CLAUDE.md
check "R12b CLAUDE.md has no CodeRabbit mention (decision closed, row dropped)" ok $?

# --- R13: repo-wide invariant — ponytail is gone from every skill + reference,
# scoped to skills/ + CLAUDE.md so eval graders may still legitimately name it
# as a thing that must NOT be invoked. ---

! grep -rqi 'ponytail' plugins/raftkit-dev/skills/ CLAUDE.md 2>/dev/null
check "R13 no skill or reference file names ponytail anywhere" ok $?

# --- R13b-R13e: the CodeRabbit closure reaches the surfaces R5-R7 missed —
# the /help commands and setup-project — without dropping the config file the
# pack still installs. ---

! grep -rqi 'coderabbit' plugins/*/commands/ 2>/dev/null
check "R13b no plugin command page names CodeRabbit (help pages included)" ok $?

SETUP="$DEV/setup-project/SKILL.md"
cr_bullet=$(grep -i -A2 'CodeRabbit licensing' "$SETUP")
! grep -qi 'open' <<<"$cr_bullet"
check "R13c setup-project no longer calls the licensing decision open" ok $?

grep -q '1216551482947559' <<<"$cr_bullet" && grep -qi 'closed 2026-07-14' <<<"$cr_bullet"
check "R13d setup-project states the decision is closed, citing it with its date" ok $?

grep -qi 'coderabbit.yaml' "$SETUP"
check "R13e setup-project still installs the CodeRabbit config asset (scope pin)" ok $?

# --- R14-R15: fix the two things that would otherwise regress ---

! grep -q "grep -q 'ponytail:ponytail-review'" tests/workflow-integration.test.sh
check "R14 workflow-integration.test.sh W12 no longer requires ponytail presence" ok $?

evc="plugins/raftkit-dev/evals/workflow-integration/simplify-scoped-dispatch/graders/criteria.md"
grep -qi 'not.*invok.*ponytail\|no ponytail\|does not.*dispatch.*ponytail' "$evc"
check "R15 simplify-scoped-dispatch eval now requires ponytail is NOT invoked" ok $?

# --- R16: the new eval bundle for review-seams ---

n=$(find plugins/raftkit-dev/evals/review-seams -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${n:-0}" -ge 3 ]] \
  && ! find plugins/raftkit-dev/evals/review-seams -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print | grep -q . \
  && ! find plugins/raftkit-dev/evals/review-seams -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print | grep -q .
check "R16a >=3 review-seams eval cases, each with prompt.md + graders" ok $?

! grep -l '1216551482947559' plugins/raftkit-dev/evals/review-seams/*/prompt.md 2>/dev/null | grep -q .
check "R16b eval prompts do not leak the Asana GID (no-answer-leak)" ok $?

# --- R17-R18: version bump + description lockstep ---

node -e '
  const v = JSON.parse(require("fs").readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json","utf8")).version.split(".").map(Number);
  const min = [0, 23, 0];
  const cmp = v[0]-min[0] || v[1]-min[1] || v[2]-min[2];
  process.exit(cmp >= 0 ? 0 : 1);
'
check "R17 raftkit-dev version is at least 0.23.0" ok $?

node -e '
  const fs = require("fs");
  const m = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
  const p = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
  const entry = m.plugins.find(x => x.name === "raftkit-dev");
  process.exit(entry && entry.description === p.description ? 0 : 1);
'
check "R18 marketplace.json description still matches raftkit-dev plugin.json" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
