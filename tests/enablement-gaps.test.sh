#!/usr/bin/env bash
# Deterministic contract suite for the four PM enablement gaps
# (Asana 1217126224215119, from the 3 Aug PM review call):
#   gap 1  which skill NOT to use — a "Not for" boundary per skill row
#   gap 2  where project context lives and how it persists overnight
#   gap 3  QA edge-case depth in stories is by design, not a defect
#   gap 4  output quality tracks input context — feed everything, never guess
#
# Requirement -> evidence matrix:
#   R-1  pm help table carries a Not for column, every row filled ... C1
#   R-2  boundary rows redirect to the right sibling skill .......... C2
#   R-3  context-lives paragraph: Profile + same-Cowork-project ..... C3
#   R-4  QA-depth-by-design rule in pm help ......................... C4
#   R-5  context-in/quality-out rule in pm help ..................... C5
#   R-6  qa help states stories arrive happy-path by design ......... C6
#   R-7  qa help table carries a Not for column, every row filled ... C7
#   R-8  pm + qa versions bumped .................................... C8
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

PMHELP=plugins/raftkit-pm/commands/help.md
QAHELP=plugins/raftkit-qa/commands/help.md
PMMANIFEST=plugins/raftkit-pm/.claude-plugin/plugin.json
QAMANIFEST=plugins/raftkit-qa/.claude-plugin/plugin.json
sec() { sed -n "/$2/,/$3/p" "$1" 2>/dev/null; }
flat() { tr '\n' ' ' <<<"$1" | tr -s ' '; }

# <file> <skill> -> that skill's table row (searched inside ## Skills only,
# because prose elsewhere also backticks skill names)
row() { sec "$1" '^## Skills' '^## ' | grep -F "| \`$2\` |" | head -1; }
notfor() { awk -F'|' '{print $5}' <<<"$1"; } # 4th data cell of a table row

# C1 · pm skills table has a Not for column and no skill row leaves it empty.
pmtable=$(sec "$PMHELP" '^## Skills' '^## ')
grep -qE '^\| *Skill *\|.*\| *Not for *\|' <<<"$pmtable"
check "C1a pm help table header carries a Not for column" ok $?
# every data row must positively match the 4-filled-cell shape — an absence
# count would pass vacuously while the column doesn't exist at all.
filled=$(grep -cE '^\| `[a-z-]+` \| [^|]+ \| [^|]+ \| [^|]*[^| ] *\|$' <<<"$pmtable")
total=$(grep -c '^| `' <<<"$pmtable")
[[ "$total" -ge 8 && "$filled" -eq "$total" ]]
check "C1b all $total pm skill rows fill the Not for cell" ok $?

# C2 · boundaries redirect to the sibling that owns the job.
grep -qi 'estimation'        <<<"$(notfor "$(row "$PMHELP" user-story)")"
check "C2a user-story's boundary points at estimation" ok $?
grep -qi 'user-story'        <<<"$(notfor "$(row "$PMHELP" estimation)")"
check "C2b estimation's boundary points at user-story" ok $?
grep -qi 'user-story'        <<<"$(notfor "$(row "$PMHELP" brainstorm)")"
check "C2c brainstorm's boundary points at user-story" ok $?
grep -qi 'status-update'     <<<"$(notfor "$(row "$PMHELP" meeting-decisions)")"
check "C2d meeting-decisions' boundary points at status-update" ok $?
grep -qi 'meeting-decisions' <<<"$(notfor "$(row "$PMHELP" status-update)")"
check "C2e status-update's boundary points at meeting-decisions" ok $?
grep -qiE 'audits only|it audits' <<<"$(notfor "$(row "$PMHELP" story-readiness)")"
check "C2f story-readiness' boundary says it audits, never fixes" ok $?

# C3 · where project context lives, and how it survives to tomorrow.
# End pattern is a single BRE (no \| alternation — BSD sed treats it literally).
livesflat=$(flat "$(sec "$PMHELP" '^## Where things live' '^Close by')")
grep -qi 'Project Profile' <<<"$livesflat" && grep -qiE 'names (exactly )?where it wrote' <<<"$livesflat"
check "C3a Profile named as the context home, destination stated on completion" ok $?
grep -qiE 'same Cowork project' <<<"$livesflat" && grep -qiE 'memory' <<<"$livesflat"
check "C3b persistence rule: next chat in the same Cowork project, via memory" ok $?

# C4 · the story's edge-case contract, stated accurately: stories carry the
# WEESLD frame (a blank row IS a readiness defect); case-level enumeration is
# raftkit-qa's; a state QA finds uncovered routes back via amend mode.
rulesflat=$(flat "$(sec "$PMHELP" '^## Rules that always apply' '^## ')")
grep -qiE 'WEESLD frame' <<<"$rulesflat" && grep -qiE 'raftkit-qa' <<<"$rulesflat" \
  && grep -qiE 'blank WEESLD row is a readiness defect' <<<"$rulesflat" \
  && grep -qiE 'amend mode' <<<"$rulesflat"
check "C4 pm rules: WEESLD frame contract, readiness defect, amend-mode return path" ok $?

# C5 · context in, quality out.
grep -qiE 'quality tracks input context' <<<"$rulesflat" && grep -qiE 'never guess|asks?.*never guess' <<<"$rulesflat"
check "C5 pm rules: output quality tracks input context; thin sources get asked" ok $?

# C6 · qa help states the same contract from QA's side: stories carry the
# WEESLD frame, case-level depth is created here, gaps route back via amend mode.
qaflat=$(flat "$(cat "$QAHELP")")
grep -qiE 'WEESLD frame' <<<"$qaflat" && grep -qiE 'amend mode' <<<"$qaflat" \
  && grep -qiE 'flags any state the story leaves uncovered' <<<"$qaflat"
check "C6 qa help: WEESLD frame stated, uncovered states flagged and routed back" ok $?

# C7 · qa skills table has a Not for column and all 4 rows fill it.
qatable=$(sec "$QAHELP" '^## Skills' '^## ')
grep -qE '^\| *Skill *\|.*\| *Not for *\|' <<<"$qatable"
check "C7a qa help table header carries a Not for column" ok $?
filled=$(grep -cE '^\| `[a-z-]+` \| [^|]+ \| [^|]+ \| [^|]*[^| ] *\|$' <<<"$qatable")
total=$(grep -c '^| `' <<<"$qatable")
[[ "$total" -ge 4 && "$filled" -eq "$total" ]]
check "C7b all $total qa skill rows fill the Not for cell" ok $?
grep -qi 'retest' <<<"$(notfor "$(row "$QAHELP" file-bug)")"
check "C7c file-bug's boundary points at retest" ok $?

# C8 · versions bumped: pm past 0.21.x, qa past 0.8.0.
python3 - "$PMMANIFEST" <<'EOF'
import json,sys
v=[int(x) for x in json.load(open(sys.argv[1]))["version"].split(".")]
sys.exit(0 if v>=[0,22,0] else 1)
EOF
check "C8a raftkit-pm version >= 0.22.0" ok $?
python3 - "$QAMANIFEST" <<'EOF'
import json,sys
v=[int(x) for x in json.load(open(sys.argv[1]))["version"].split(".")]
sys.exit(0 if v>=[0,9,0] else 1)
EOF
check "C8b raftkit-qa version >= 0.9.0" ok $?

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
