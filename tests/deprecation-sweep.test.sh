#!/usr/bin/env bash
# Deterministic contract suite for the deprecation-sweep skill
# (Asana 1217123743893926 — step 3 of Ashit's process, packaged; steps 1-2,
# the shared per-project Gmail, are an open founder question and stay out).
#
# Requirement -> evidence matrix:
#   R-1  skill exists; description carries the triggers ......... C1
#   R-2  the routine is read-only — reports, creates nothing .... C2
#   R-3  twice-daily schedule per Ashit's process ............... C3
#   R-4  sweep surfaces named: Asana, Slack, email ............... C4
#   R-5  flag catalog: deprecation/EOL, price, migration, expiry . C5
#   R-6  every flag cites its source and names the deadline ...... C6
#   R-7  founder-review label on commercial items ................ C7
#   R-8  cloud-not-local routine rule ............................ C8
#   R-9  shared-Gmail open question named, with its task GID ..... C9
#   R-10 help row present with a filled Not for cell ............. C10
#   R-11 pm version bumped ....................................... C11
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

SKILL=plugins/raftkit-pm/skills/deprecation-sweep/SKILL.md
PMHELP=plugins/raftkit-pm/commands/help.md
PMMANIFEST=plugins/raftkit-pm/.claude-plugin/plugin.json
sec() { sed -n "/$2/,/$3/p" "$1" 2>/dev/null; }
flat() { tr '\n' ' ' <<<"$1" | tr -s ' '; }

[[ -f "$SKILL" ]]
check "C1a deprecation-sweep SKILL.md exists" ok $?
desc=$(sed -n '/^description:/,/^---$/p' "$SKILL" 2>/dev/null)
grep -qi 'deprecation' <<<"$desc" && grep -qi 'sweep' <<<"$desc"
check "C1b description carries the deprecation-sweep triggers" ok $?

body=$(flat "$(cat "$SKILL" 2>/dev/null)")
# The routine prompt itself, not the surrounding prose — several contracts are
# only real if they sit INSIDE the fenced block a PM pastes into the routine.
promptflat=$(flat "$(sed -n '/^```text$/,/^```$/p' "$SKILL" 2>/dev/null)")

# C2 · the routine only reads and reports; nothing is created or edited, so
# no write-protocol exception is needed — and the skill says both halves.
grep -qiE 'creates nothing|files nothing' <<<"$body" && grep -qiE 'no (new )?(write-protocol )?exception' <<<"$body"
check "C2a read-only contract stated, with the no-exception-needed rationale" ok $?
# The prose is not enough: the pasted prompt must open with the read-only order.
grep -q 'Read, do not write' <<<"$promptflat" \
  && grep -q 'Create nothing, edit nothing, send nothing, file nothing' <<<"$promptflat"
check "C2b the prompt block itself opens with the read-only order" ok $?

# C3 · twice daily, morning and post-lunch.
grep -qiE 'twice.daily|twice a day' <<<"$body" && grep -qiE 'post-lunch' <<<"$body"
check "C3 twice-daily schedule, morning and post-lunch" ok $?

# C4 · the three sweep surfaces.
grep -qi 'Asana' <<<"$body" && grep -qi 'Slack' <<<"$body" && grep -qiE 'email|inbox|Gmail' <<<"$body"
check "C4 sweep covers Asana, Slack, and email" ok $?

# C5 · the flag catalog, all four families.
grep -qiE 'end.of.(support|life)|deprecat' <<<"$body" && grep -qiE 'price' <<<"$body" \
  && grep -qiE 'migration' <<<"$body" && grep -qiE 'expir' <<<"$body"
check "C5 flag catalog: deprecation/EOL, price change, migration, expiry" ok $?

# C6 · citations and deadlines on every flag — inside the prompt block, where
# the routine actually reads them; prose mentions elsewhere don't count.
grep -qi 'cited exactly' <<<"$promptflat" && grep -qi 'the deadline it names' <<<"$promptflat"
check "C6 the prompt requires per-flag citations and the named deadline" ok $?

# C7 · commercial items carry the founder-review label.
grep -qE 'FOUNDER REVIEW' <<<"$body"
check "C7 FOUNDER REVIEW label on budget/commitment items" ok $?

# C8 · cloud routine, not local.
grep -qiE 'cloud' <<<"$body" && grep -qiE 'local schedule|not local|machine is on' <<<"$body"
check "C8 cloud-not-local routine rule stated" ok $?

# C9 · the open founder question is named WITH its task in the same breath —
# an unrelated citation of the same GID elsewhere must not satisfy this.
grep -qiE 'open founder question on Asana task .?1217123743893926' <<<"$body" \
  && grep -qiE 'shared Gmail' <<<"$body"
check "C9 shared-Gmail open question named with its Asana task" ok $?

# C10 · help table row exists and fills its Not for cell.
helprow=$(sec "$PMHELP" '^## Skills' '^## ' | grep -F '| `deprecation-sweep` |' | head -1)
[[ -n "$helprow" ]] && [[ -n "$(awk -F'|' '{gsub(/ /,"",$5); print $5}' <<<"$helprow")" ]]
check "C10 pm help row for deprecation-sweep with a filled Not for cell" ok $?

# C11 · pm version bumped past A2's 0.22.0.
python3 - "$PMMANIFEST" <<'EOF'
import json,sys
v=[int(x) for x in json.load(open(sys.argv[1]))["version"].split(".")]
sys.exit(0 if v>=[0,23,0] else 1)
EOF
check "C11 raftkit-pm version >= 0.23.0" ok $?

# C12 · the plugin description's skill roster names the new skill.
python3 - "$PMMANIFEST" <<'EOF'
import json,sys
sys.exit(0 if 'deprecation sweep' in json.load(open(sys.argv[1]))["description"].lower() else 1)
EOF
check "C12 pm plugin description roster names deprecation sweep" ok $?

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
